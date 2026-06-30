import { servers } from "../config/servers.js";

let current = 0;

export function getServerOrder() {
    const activeServers = servers.filter(server => server.active);

    if (activeServers.length === 0) {
        return [];
    }

    const start = current % activeServers.length;

    current = (current + 1) % activeServers.length;

    const order = [];
    for (let i = 0; i < activeServers.length; i++) {
        order.push(activeServers[(start + i) % activeServers.length]);
    }

    return order;
}