import axios from "axios";

export const proxyRequest = async (req, res) => {
    const servers = req.serversPool;

    for (const server of servers) {
        try {
            console.log(`🔄 Routing -> Server ${server.id} (${server.url})`);

            const response = await axios({
                method: req.method,
                url: `${server.url}${req.originalUrl}`,
                data: req.body,
                timeout: 8000,
                headers: {
                    "Content-Type": "application/json",
                    Authorization: req.headers.authorization || "",
                }
            });

            console.log(` Request processed successfully by Server ${server.id}`);
            return res.status(response.status).json(response.data);

        } catch (err) {
            console.log(` Server ${server.id} encountered an issue`);

            if (err.response) {
                const status = err.response.status;
                console.log(` Server ${server.id} returned HTTP ${status}`);

                if (status === 404 || status >= 500) {
                    console.log(`⏭️ Skipping Server ${server.id} and trying next backup server...`);
                    continue;
                }

                return res.status(status).json(err.response.data);
            }

            // True network failure or connection timeout. Loop continues automatically.
            console.log(`💔 Infrastructure Failure on ${server.id}: ${err.message}`);
        }
    }

    // This triggers only if EVERY server in the pool threw a 404, 5xx, or timed out
    return res.status(503).json({
        success: false,
        message: "All operational backends failed to serve this request (Timeouts/404s/500s)."
    });
};