import Meal from "../models/Meal.js";
import Fine from "../models/fine.model.js";
import ShoppingItem from "../models/shopping.model.js";
import StudentSubscription from "../models/StudentSubscription.js";
import mongoose from "mongoose";
import moment from 'moment';

import { getActiveMealsAndConsumption, getStudentFinesAndUsage, getProcurementExpenses } from "./utils/financeHelpers.js";




/**
 * @desc    Get structural meal cycle bounds including cancelled day offsets
 * @route   GET /api/finance/meal-cycle-bounds
 * @access  Private (Manager/Student)
 */
export const getFinanceData = async (req, res) => {
    try {
        const hostelId = req.user.hostelId;

        const today = new Date();
        today.setHours(0, 0, 0, 0);

        // Fetch up to 90 historical meals to parse structural cycle boundaries
        const meals = await Meal.find({ hostelId: hostelId })
            .select("date morning.mealsNum night.mealsNum")
            .sort({ _id: -1 }) 
            .limit(90);

        if (!meals || meals.length === 0) {
            return res.status(200).json({ success: true, cycles: [] });
        }

        // 1. Map all meals chronologically, extracting structural sequence counts
        const chronologicalMeals = meals.reverse().map(m => {
            const [day, month, year] = m.date.split("/");
            const morningNum = parseInt(m.morning?.mealsNum || "0", 10);
            const nightNum = parseInt(m.night?.mealsNum || "0", 10);
            
            // Safe fallbacks: target the latest active meal of the day chronologically
            let dayMealsNum = 0;
            if (nightNum > 0) {
                dayMealsNum = nightNum;
            } else if (morningNum > 0) {
                dayMealsNum = morningNum;
            }

            return {
                originalStr: m.date,
                timestamp: new Date(`${year}-${month}-${day}T00:00:00.000Z`),
                morningNum,
                nightNum,
                mealsNum: dayMealsNum
            };
        });

        const rawCycles = [];
        let currentCycleList = [];
        let lastActiveMealsNum = 0;

        // 2. Group meals into cycle arrays (including cancelled mealsNum === 0 days)
        for (let i = 0; i < chronologicalMeals.length; i++) {
            const currentItem = chronologicalMeals[i];

            if (currentCycleList.length > 0) {
                // 🌟 Trigger a new cycle boundary push if:
                // a) Current meal explicitly resets to 1 AND the current cycle has active logs
                const isNewCycleExplicitReset = currentItem.mealsNum === 1 && lastActiveMealsNum > 0;
                
                // b) Current meal rolls back to a lower number than the last active meal
                const isNewCycleRollback = currentItem.mealsNum > 0 && currentItem.mealsNum < lastActiveMealsNum;
                
                // c) The last active meal number has met or exceeded the 60-meal structural threshold
                const isNewCycleLimitReached = lastActiveMealsNum >= 60;

                if (isNewCycleExplicitReset || isNewCycleRollback || isNewCycleLimitReached) {
                    rawCycles.push([...currentCycleList]);
                    currentCycleList = [];
                    lastActiveMealsNum = 0;
                }
            }

            currentCycleList.push(currentItem);

            if (currentItem.mealsNum > 0) {
                lastActiveMealsNum = currentItem.mealsNum;
            }
        }
        
        if (currentCycleList.length > 0) {
            rawCycles.push([...currentCycleList]);
        }

        // 3. Compile and map cycles with active statuses and correct boundaries
        const compiledCycles = rawCycles.map((cycleDays, index) => {
            const firstDay = cycleDays[0];
            const lastDay = cycleDays[cycleDays.length - 1];
            const cycleIndex = index + 1;

            // Safe calendar midnight boundaries
            const firstTimestamp = new Date(firstDay.timestamp);
            firstTimestamp.setHours(0, 0, 0, 0);

            const lastTimestamp = new Date(lastDay.timestamp);
            lastTimestamp.setHours(23, 59, 59, 999);

            const isTodayInsideCycle = today >= firstTimestamp && today <= lastTimestamp;

            let label = `Cycle ${cycleIndex} (${firstDay.originalStr} to ${lastDay.originalStr})`;
            if (isTodayInsideCycle) {
                label = `Live Cycle ${cycleIndex} (${firstDay.originalStr} to ${lastDay.originalStr} - Active Now!)`;
            }

            return {
                cycleIndex: cycleIndex,
                startDateStr: firstDay.originalStr,
                endDateStr: lastDay.originalStr,
                isCurrentActive: isTodayInsideCycle,
                label: label
            };
        });

        // Ensure at least one cycle is marked active (fallback to newest)
        const hasActive = compiledCycles.some(c => c.isCurrentActive);
        if (!hasActive && compiledCycles.length > 0) {
            compiledCycles[compiledCycles.length - 1].isCurrentActive = true;
        }

        res.status(200).json({
            success: true,
            cycles: compiledCycles.reverse() // Keep newest cycles at the top of the Flutter list
        });

    } catch (error) {
        res.status(500).json({ 
            success: false, 
            message: "Error calculating real-time active cycles.", 
            error: error.message 
        });
    }
};



export const getFinanceAuditReport = async (req, res) => {
    try {
        const hostelId = req.user.hostelId;
        const { startDateStr, endDateStr } = req.query;

        if (!startDateStr || !endDateStr) {
            return res.status(400).json({
                success: false,
                message: "Please include both startDateStr and endDateStr parameters.",
            });
        }

        // 1. Convert DD/MM/YYYY text bounds into standard Date Objects
        const [startDay, startMonth, startYear] = startDateStr.split("/");
        const [endDay, endMonth, endYear] = endDateStr.split("/");
        const trueStartDate = new Date(`${startYear}-${startMonth}-${startDay}T00:00:00.000Z`);
        const trueEndDate = new Date(`${endYear}-${endMonth}-${endDay}T23:59:59.999Z`);

        // 2. Fetch and aggregate meal tracking maps via helper
        const { totalMealsCount, targetCycleDates, usageAggregatorMap } =
            await getActiveMealsAndConsumption(hostelId, trueStartDate, trueEndDate);

        // 3. Extract matching student balance allocations via helper
        const { totalIncomePool, finalizedStudentUsageList } =
            await getStudentFinesAndUsage(hostelId, trueStartDate, trueEndDate, usageAggregatorMap);

        // 4. Calculate expense deductions list via helper
        const { totalSpentExpenses, formattedProcurements } =
            await getProcurementExpenses(hostelId, targetCycleDates);

        console.log("Audit Report Debug Info:", {
            targetCycleDates,
            hostelId,
            totalSpentExpenses,
            formattedProcurements
        });

        // 5. Send payload back to Flutter application
        return res.status(200).json({
            success: true,
            summary: {
                mealsServed: totalMealsCount,
                totalCollections: totalIncomePool,
                totalExpenses: totalSpentExpenses,
                netPoolBalance: totalIncomePool - totalSpentExpenses
            },
            studentUsage: finalizedStudentUsageList,
            procurementItems: formattedProcurements
        });

    } catch (error) {
        return res.status(500).json({
            success: false,
            message: "Error compiling audit calculation parameters.",
            error: error.message,
        });
    }
};