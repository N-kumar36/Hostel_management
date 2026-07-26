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
        console.log(`Routing -> Server ${currentServer.id} (${currentServer.url})`);

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
                    
                    // FIXED BODY RESTREAMING:
                    // Check if express parsed a body (even an empty object `{}`)
                    if (req.body && typeof req.body === "object" && !req.headers["content-type"]?.includes("multipart/form-data")) {
                        const bodyData = JSON.stringify(req.body);
                        proxyReq.setHeader('Content-Type', 'application/json');
                        proxyReq.setHeader('Content-Length', Buffer.byteLength(bodyData));
                        
                        // Always write the body data (e.g. `{}`) so the proxy stream finishes
                        proxyReq.write(bodyData);
                    }
                },
                error: (err, req, res) => {
                    console.log(`Server ${currentServer.id} encountered an issue: ${err.message}`);
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