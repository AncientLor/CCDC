import socket
import os
import zipfile
import tqdm

authLog = "/var/log/auth.log"
sysLog = "/var/log/syslog"

def checkBackupFolder():
    if os.path.exists("backups"):
        return
    else:
        print("Making backups directory.")
        os.mkdir("backups")


def copyFile(logFile):
        checkBackupFolder()
        if os.path.isfile(logFile):
            readLog = open(logFile, "rb")
            baseFile = logFile.split("/")
            baseFile = baseFile[len(baseFile)-1]
            bakFile = "backups/"+ baseFile + ".bak"
            newLog = open(bakFile, "wb")
            for line in readLog:
                newLog.write(line)
            
            newLog.close()
            readLog.close()
        else:
            raise ValueError("File does not exist.")

def zipLogs():
    logs = os.listdir("backups")
    with zipfile.ZipFile("backups/backups.zip", "w") as z:
        for log in logs:
            z.write(log)


def backupAllLogs():
    checkBackupFolder()
    hostName = socket.gethostname()
    backupFile = "backups/logbackup_" + hostName + ".zip"
    zf = zipfile.ZipFile(backupFile, "w", zipfile.ZIP_DEFLATED)
    for dirname, subdirs, files in os.walk("/var/log/"):
            for file in files:
                zf.write(os.path.join(dirname, file))
    zf.close()
    return backupFile


def sendFile(backupFile):
    print(backupFile)
    remoteIP = "192.168.1.15"
    remotePort = 80
    fileSize = os.path.getsize(backupFile)
    baseName = backupFile.split("/")
    baseName = baseName[len(baseName)-1]
    bufferSize = 4094
    spacer = "<SEPARATOR>"
    
    s = socket.socket()
    s.connect((remoteIP, remotePort))
    s.send(f"{backupFile}{spacer}{fileSize}".encode())
    progress = tqdm.tqdm(range(fileSize), f"Sending {backupFile}", unit="B", unit_scale=True, unit_divisor=1024)
    with open(backupFile, "rb") as f:
        while True:
            readBytes = f.read(bufferSize)
            if not readBytes:
                break
            s.sendall(readBytes)
            progress.update(len(readBytes))
    f.close()
    s.close()
    print("Done.")


def main():
    print("Making Backup...")
    backupFile = backupAllLogs()
    print("Sending Backup...")
    sendFile(backupFile)

main()
