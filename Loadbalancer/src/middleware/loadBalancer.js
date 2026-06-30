import { getServerOrder } from "../utils/roundRobin.js";

export async function chooseServer(req, res, next) {
    try {
        const orderedServers = getServerOrder();

        if (!orderedServers || orderedServers.length === 0) {
            return res.status(503).json({
                success: false,
                message: "No healthy backend servers available right now"
            });
        }

        // Attach the prioritized server pool array onto the req object 
        // so the controller can loop through them if the primary fails.
        req.serversPool = orderedServers;

        console.log(` Request scheduled across ${orderedServers.length} active backends.`);
        next();

    } catch (error) {
        console.error("Load Balancer Error:", error.message);
        return res.status(500).json({
            success: false,
            message: "Internal Load Balancer Error"
        });
    }
}