import { createProxyMiddleware } from "http-proxy-middleware";

export const proxyRequest = (req, res, next) => {
    const servers = req.serversPool;
    
    if (!servers || servers.length === 0) {
        return res.status(503).json({ success: false, message: "No active backends found." });
    }

    let serverIndex = 0;

    const tryNextServer = () => {
        if (serverIndex >= servers.length) {
            return res.status(503).json({
                success: false,
                message: "All operational backends failed to serve this request (Timeouts/Failures)."
            });
        }

        const currentServer = servers[serverIndex];
        console.log(`🔄 Routing -> Server ${currentServer.id} (${currentServer.url})`);

        // Create a dynamic proxy instance for this server
        const proxy = createProxyMiddleware({
            target: currentServer.url,
            changeOrigin: true, // Crucial for Vercel deployment targets
            proxyTimeout: 15000, 
            timeout: 15000,
            on: {
                proxyReq: (proxyReq, req, res) => {
                    // Forward authorization headers if they exist
                    if (req.headers.authorization) {
                        proxyReq.setHeader("Authorization", req.headers.authorization);
                    }
                    
                    // If express.json() already parsed the body, we need to restream it
                    if (req.body && Object.keys(req.body).length > 0 && !req.headers["content-type"]?.includes("multipart/form-data")) {
                        const bodyData = JSON.stringify(req.body);
                        proxyReq.setHeader('Content-Type', 'application/json');
                        proxyReq.setHeader('Content-Length', Buffer.byteLength(bodyData));
                        proxyReq.write(bodyData);
                    }
                },
                error: (err, req, res) => {
                    console.log(`⚠️ Server ${currentServer.id} encountered an issue: ${err.message}`);
                    serverIndex++;
                    tryNextServer(); // Fallback to the next backup server automatically
                }
            }
        });

        // Execute the proxy
        proxy(req, res, next);
    };

    tryNextServer();
};