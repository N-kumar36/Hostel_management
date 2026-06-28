import Meal from "../models/Meal.js";
import Fine from "../models/fine.model.js";
import ShoppingItem from "../models/shopping.model.js";
import StudentSubscription from "../models/StudentSubscription.js";
import mongoose from "mongoose";
import moment from 'moment';

import { getActiveMealsAndConsumption, getStudentFinesAndUsage, getProcurementExpenses } from "./utils/financeHelpers.js";




export const getFinanceData = async (req, res) => {
    try {
        const hostelId = req.user.hostelId;

        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const meals = await Meal.find({ hostelId: hostelId })
            .select("date morning.mealsNum night.mealsNum")
            .sort({ _id: -1 }) 
            .limit(90);

        if (!meals || meals.length === 0) {
            return res.status(200).json({ success: true, cycles: [] });
        }

        //  OPTIMIZATION 2: Reverse back to chronological order once instead of sorting from scratch
        const chronologicalMeals = meals.reverse().map(m => {
            const [day, month, year] = m.date.split("/");
            return {
                originalStr: m.date,
                timestamp: new Date(`${year}-${month}-${day}`),
                mealsNum: parseInt(m.morning?.mealsNum || m.night?.mealsNum || "0")
            };
        });

        const rawCycles = [];
        let currentCycleList = [];

        // Group into cycle arrays based on cycle reset markers
        for (let i = 0; i < chronologicalMeals.length; i++) {
            const currentItem = chronologicalMeals[i];
            if (currentItem.mealsNum === 0) continue;

            if (currentCycleList.length > 0) {
                const lastItem = currentCycleList[currentCycleList.length - 1];
                if (currentItem.mealsNum < lastItem.mealsNum || currentItem.mealsNum === 1) {
                    rawCycles.push([...currentCycleList]);
                    currentCycleList = [];
                }
            }
            currentCycleList.push(currentItem);
        }
        if (currentCycleList.length > 0) {
            rawCycles.push([...currentCycleList]);
        }

        // Map and identify active cycle blocks
        const compiledCycles = rawCycles.map((cycleDays, index) => {
            const firstDay = cycleDays[0];
            const lastDay = cycleDays[cycleDays.length - 1];
            const cycleIndex = index + 1;

            const isTodayInsideCycle = today >= firstDay.timestamp && today <= lastDay.timestamp;

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

        const hasActive = compiledCycles.some(c => c.isCurrentActive);
        if (!hasActive && compiledCycles.length > 0) {
            compiledCycles[compiledCycles.length - 1].isCurrentActive = true;
        }

        res.status(200).json({
            success: true,
            cycles: compiledCycles.reverse() // Keep newest cycles at the top of the Flutter list
        });

    } catch (error) {
        res.status(500).json({ success: false, message: "Error calculating real-time active cycles.", error: error.message });
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