#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <winsock2.h>
#include <windows.h>
#include <process.h>
#include <winreg.h>
#include <time.h>

#define TARGET_HOST "192.168.1.100"
#define TARGET_PORT 3389
#define LOCAL_PORT 1337
#define PROXY_SERVER "proxy.corporate.net:8080"
#define VPN_CONFIG "C:\\Program Files\\CorporateVPN\\config.ovpn"
#define CREDENTIALS_FILE "C:\\Windows\\System32\\config\\systemcredentials.enc"
#define LOG_FILE "C:\\Windows\\Temp\\connection_log.txt"

typedef struct {
    int is_connected;
    SOCKET socket;
    HANDLE monitor_thread;
} NetworkConnector;

int check_firewall() {
    char command[256];
    snprintf(command, sizeof(command), "netsh advfirewall firewall add rule name=CorporateConnection dir=in action=allow protocol=TCP localport=%d remoteip=%s", LOCAL_PORT, TARGET_HOST);
    return system(command) == 0;
}

int set_registry_proxy() {
    HKEY key;
    if (RegOpenKeyEx(HKEY_CURRENT_USER, "Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings", 0, KEY_SET_VALUE, &key) == ERROR_SUCCESS) {
        DWORD proxy_enable = 1;
        RegSetValueEx(key, "ProxyEnable", 0, REG_DWORD, (const BYTE*)&proxy_enable, sizeof(proxy_enable));
        RegSetValueEx(key, "ProxyServer", 0, REG_SZ, (const BYTE*)PROXY_SERVER, strlen(PROXY_SERVER) + 1);
        RegSetValueEx(key, "ProxyOverride", 0, REG_SZ, (const BYTE*)"<local>", strlen("<local>") + 1);
        RegCloseKey(key);
        return 1;
    }
    return 0;
}

int start_vpn() {
    if (PathFileExists("C:\\Program Files\\OpenVPN\\bin\\openvpn.exe")) {
        STARTUPINFO si = { sizeof(si) };
        PROCESS_INFORMATION pi;
        si.dwFlags = STARTF_USESHOWWINDOW;
        si.wShowWindow = SW_HIDE;
        if (CreateProcess("C:\\Program Files\\OpenVPN\\bin\\openvpn.exe", 
                          "--config C:\\Program Files\\CorporateVPN\\config.ovpn --auth-user-pass C:\\Windows\\System32\\config\\systemcredentials.enc --daemon", 
                          NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi)) {
            Sleep(5000);
            return 1;
        }
    }
    return 0;
}

int test_connection() {
    SOCKET sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock == INVALID_SOCKET) return 0;

    struct sockaddr_in server;
    server.sin_family = AF_INET;
    server.sin_port = htons(TARGET_PORT);
    server.sin_addr.s_addr = inet_addr(TARGET_HOST);

    int result = connect(sock, (struct sockaddr*)&server, sizeof(server));
    closesocket(sock);
    return result == 0;
}

void log_connection_status() {
    FILE *f = fopen(LOG_FILE, "a");
    if (f) {
        time_t now = time(NULL);
        fprintf(f, "%s - Connection active to %s:%d\n", ctime(&now), TARGET_HOST, TARGET_PORT);
        fclose(f);
    }
}

unsigned __stdcall monitor_connection(void *arg) {
    NetworkConnector *nc = (NetworkConnector *)arg;
    while (nc->is_connected) {
        if (!test_connection()) {
            printf("Connection lost! Reconnecting...\n");
            // Implement reconnect logic here
        }
        log_connection_status();
        Sleep(10000); // Check every 10 seconds
    }
    return 0;
}

int main() {
    NetworkConnector nc = {0};
    nc.is_connected = 1;

    // Example usage
    check_firewall();
    set_registry_proxy();
    start_vpn();
    
    nc.monitor_thread = (HANDLE)_beginthreadex(NULL, 0, monitor_connection, &nc, 0, NULL);
    WaitForSingleObject(nc.monitor_thread, INFINITE);
    CloseHandle(nc.monitor_thread);
    
    return 0;
}