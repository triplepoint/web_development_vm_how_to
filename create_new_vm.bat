@echo off

if (%1)==() goto ERROR

set ISO=E:\Users\username\Downloads\mini.iso
set VM_DIR=E:\Users\username\VirtualBox VMs
set VM_NAME=%1
set VM_SHARED_DIRECTORY=E:\Users\username\workspace

:: Create the new disk
@echo on
VboxManage createhd --filename "%VM_DIR%\%VM_NAME%\%VM_NAME%.vdi" --size 10240 --format VDI --variant Standard

:: Create the new vm
VboxManage createvm --name "%VM_NAME%" --ostype Ubuntu_64 --register
VboxManage modifyvm "%VM_NAME%" --memory 2048 --vram 12 --acpi on --ioapic on --cpus 1 --rtcuseutc on --boot1 dvd --boot2 disk --boot3 none --boot4 none --audio none
VboxManage modifyvm "%VM_NAME%" --nic1 nat --nictype1 82540EM
VboxManage modifyvm "%VM_NAME%" --nic2 hostonly --nictype2 82540EM --hostonlyadapter2 "VirtualBox Host-Only Ethernet Adapter"

:: Create the HD controller and attach the disk
VBoxManage storagectl "%VM_NAME%" --name "SATA Controller" --add sata --controller IntelAHCI
VBoxManage storageattach "%VM_NAME%" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "%VM_DIR%\%VM_NAME%\%VM_NAME%.vdi"

:: Create the DVD drive controller and attach the CD ROM ISO
VBoxManage storagectl "%VM_NAME%" --name "IDE Controller" --add ide
VBoxManage storageattach "%VM_NAME%" --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium "%ISO%"

:: Shared folders
VBoxManage sharedfolder add "%VM_NAME%" --name "shared_workspace" --hostpath "%VM_SHARED_DIRECTORY%"
@echo off

echo Done.
goto END


:ERROR
echo Missing Virtual Machine name.


:END
echo.


:: "eject" the CD ROM ISO (maybe worth doing after the install is complete)
:: VBoxManage storageattach "%VM_NAME%" --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium none
