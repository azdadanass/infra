echo must be excuted after 24h !!!!

wget http://mysqltuner.pl/ -O mysqltuner.pl
wget https://raw.githubusercontent.com/major/MySQLTuner-perl/master/basic_passwords.txt -O basic_passwords.txt
wget https://raw.githubusercontent.com/major/MySQLTuner-perl/master/vulnerabilities.csv -O vulnerabilities.csv


script_dir=$(dirname $0)

chmod +x $script_dir/mysqltuner.pl
$script_dir/mysqltuner.pl