import axios from "axios";
import { servers } from "../config/servers.js";

export async function checkServers() {
    for (const server of servers) {
        try {
            await axios.get(server.url, {
                timeout: 3000,
                validateStatus: function (status) {
                    return status < 500;
                }
            });

            server.active = true;
            console.log(` Server ${server.id} is ONLINE`);

        } catch (error) {
            server.active = false;
            console.log(` Server ${server.id} is OFFLINE: ${error.message}`);
        }
    }
}