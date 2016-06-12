#!/bin/bash
# Определяем функцию для удаления снапшота
function remove_snapshot
{
	echo "Removing snapshot $1..."
	lvremove --autobackup y -f $1
}

# Определяем функцию для удаления файлов бекапов
function remove_backup_file
{
	# Если есть хоть 1 файл бекапа - удаляем
	echo "Searching and removing existing backup files..."
	find $backupFolder -name "*.bak.gz" -type f -print -exec rm {} \;
}

# Объявляем переменные
DATE=`date +%Y-%m-%d--%H-%M-%S`
vm=$2;
vgFolder="/dev/$1/"
backupFolder="/mnt/backup/"

# Если задан параметр clean, то очищаем папку $backupFolder от старых файлов бекапов *.bak.gz
if [[ ${@: -1} == "clean" ]]
then
	# сообщаем, что началась очистка
	echo "Perform clean operation..."
	remove_backup_file;
	exit 0;
fi

# Если папка для бекапа указанной ВМ не существует, то создаем ее
if [ ! -d $backupFolder$vm ]
then
	echo "Backup folder $backupFolder$vm does not exist. Creating...";
	mkdir -p $backupFolder$vm;
fi


echo "Backup script start at `date +%Y-%m-%d\ %H:%M:%S`"
# дополнительные переменные
# имя снапшота. например: zabbix-backup-snap srv-demand-backup-snap win-count-backup-snap
snapshotName=$vm-backup-snap
# имя файла бекапа. например: zabbix-backup-2015-01-12--12-31-51.bak srv-demand-backup-2015-01-24--11-58-50.bak win-count-backup-2015-01-14--09-00-05.bak
backupFileName=$vm-backup-$DATE.bak.gz
# Проверяем существующие снапшоты для выбранных вм
echo "Searching existing backup snapshots for VM $vm"
if (( "`ls $vgFolder | grep $snapshotName | wc -l`" > 0 ))
then
	# Если есть, то удаляем
	echo "Warning: Backup snapshot for VM $vm exist, deleting $vgFolder$snapshotName"
	remove_snapshot "$vgFolder$snapshotName"
	# если был снапшот, значит был и файл бекапа. Ищем и удаляем
	remove_backup_file
else
	# это не ошибка, а просто уведомление
	echo "Backup snapshots for VM $vm not found"
fi
# Создаем снапшот
echo "Creating snapshot $snapshotName for VM $vm..."
lvcreate --size 20G --snapshot --name $snapshotName $vgFolder$vm
# Проверяем и удаляем файл бекапа, если он уже есть
remove_backup_file;
# выполняем сохранение в файл
echo "Starting backup snapshot $vgFolder$snapshotName for VM $vm to file $backupFolder$backupFileName"
dd if=$vgFolder$snapshotName bs=8096 | gzip -cf > $backupFolder$vm/$backupFileName
# Удаляем снапшот
echo "Removing backup snapshot $snapshotName for VM $vm..."
remove_snapshot "$vgFolder$snapshotName"
# Проверяем, что файл бекапа создался и уведомляем пользователя
if [[ -f $backupFolder$vm/$backupFileName ]]
then
	echo "File $backupFolder$vm/$backupFileName successfully created."
else
	echo "File $backupFolder$vm/$backupFileName NOT created."
	exit 1;
fi

echo "Backup script ends at `date +%Y-%m-%d\ %H:%M:%S`"
exit 0
