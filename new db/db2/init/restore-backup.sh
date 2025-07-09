backup_dir=$1

echo "try restore $backup_dir"

# restore backup locally
systemctl stop mysql
xtrabackup --prepare --target-dir=$backup_dir
rm -rf /var/lib/mysql/*
xtrabackup --copy-back --target-dir=$backup_dir --datadir=/var/lib/mysql
chown -R mysql:mysql /var/lib/mysql
systemctl start mysql