#!/bin/bash
#mysql二进制包安装脚本
#set fileformat=unix
user=mysql
group=mysql
my_cnf_dir=/etc
port=3307
mysql_bin='mysql-5.7.23-linux-glibc2.12-x86_64.tar.gz'
mysql_bin_name='mysql-5.7.23-linux-glibc2.12-x86_64'
master_ip="192.168.89.108"
slave_ip="192.168.89.110"
version="5.7"			#5.7.17,5.7.16,5.6
role="master"			#master,slave	#如果要开启组复制，这里必须为slave
gtid="on"					#on,off
base_dir=/home/mysql/mysql
data_dir=/home/mysql/mysql/data
init_mysqld=/etc/init.d/mysqld
install_mgr="no"			#yes,no
group_ip="192.168.88.126:24901,192.168.88.127:24901,192.168.88.168:24901"		#组复制ip和通信端口，通信端口要都一样并且不能是使用的端口
ip=$(ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:")    #组复制本机的IP地址，参数后面是通信地址
if [ `rpm -qa | grep cmake |wc -l` -eq 0 ];then
	for k in wget bison libaio cmake ncurses pcre openssl gcc gcc-c++ make openssl-devel zlib zlib-devel ncurses-devel unzip sysstat bc perl-DBD-MySQL perl-DBI perl-Time-HiRes perl-IO-Socket-SSL numactl rsync perl-devel perl-CPAN
	do
	yum install -y ${k}
	done
fi
id $user >& /dev/null  
if [ $? -ne 0 ];then
   groupadd $group
   useradd -g $group $user -s /sbin/nologin
fi
if [ -e ${mysql_bin} ];then
tar -zxf ${mysql_bin}
else
wget https://cdn.mysql.com/archives/mysql-5.7/${mysql_bin}
tar -zxf ${mysql_bin}
fi
mv ${mysql_bin_name} ${base_dir} 
cd ${base_dir}/support-files
cp -a mysql.server ${init_mysqld}
g='G'
if [ `free -g | grep -i mem | awk '{print $2}'` -ge '4' ];then
mem=$(echo `free -g | grep -i mem | awk '{print $2}'` - 3 | bc)
else 
mem='1'
fi

if [ `cat /proc/cpuinfo | grep siblings | awk 'NR==1{print $3}'` -ge '8' ];then
cpu=$(echo `cat /proc/cpuinfo | grep siblings | awk 'NR==1{print $3}'` / 2 | bc)
else
cpu='4'
fi
if [ ${role} == 'master' ];then
cat > /etc/my.cnf <<-EOF
[mysqld]
server-id = 1
port = ${port}
basedir = ${base_dir}
datadir = ${data_dir} 
socket = ${base_dir}/mysql.sock 
pid-file=${data_dir}/mysql.pid
skip-external-locking 
skip_name_resolve
skip-slave-start
character-set-server = utf8mb4
collation-server = utf8mb4_general_ci
init_connect='SET NAMES utf8mb4'
max_connections = 1000
max_connect_errors = 1000
max_prepared_stmt_count=1048576
max_allowed_packet = 68M
open_files_limit=65535
tmp_table_size=512M
max_heap_table_size = 512M
sort_buffer_size = 1M  #会话变量
key_buffer_size=5M
join_buffer_size =2M  #会话变量
read_buffer_size=1M   #顺序扫描缓冲
read_rnd_buffer_size=1M   #随机排序缓冲

binlog_cache_size = 12M
log_timestamps=SYSTEM
log-error=${data_dir}/mysqld.log
slow_query_log=ON
slow_query_log_file=${data_dir}/slow.log
long_query_time=1
innodb_temp_data_file_path = ibtmp1:12M:autoextend:max:5G

transaction_isolation=read-committed
log-bin=mysql-bin
max_binlog_size = 1G
binlog_row_image = full
log_bin_trust_function_creators=1
expire_logs_days=30
master-info-repository = TABLE
relay-log-info-repository = TABLE
wait_timeout=9000
slave_skip_errors = all

sql_mode=NO_ENGINE_SUBSTITUTION,STRICT_TRANS_TABLES,NO_AUTO_CREATE_USER,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO
table_open_cache=2000
innodb_open_files=65500
binlog_format = row

report-host=${master_ip}
report-port=${port}

innodb_flush_log_at_trx_commit = 2
sync_binlog = 1
innodb_buffer_pool_size = ${mem}${g}
innodb_file_per_table=1
innodb_data_file_path = ibdata1:12M;ibdata2:1G:autoextend
innodb_flush_method = O_DIRECT
innodb_log_file_size=8G
innodb_log_files_in_group=3
innodb_log_buffer_size = 12M
innodb_io_capacity=300		#SSD 3000
innodb_io_capacity_max=6000
innodb_lru_scan_depth = 2000
innodb_flush_neighbors = 1
innodb_sort_buffer_size=3108864
innodb_adaptive_flushing=1
innodb_read_io_threads=${cpu}
innodb_write_io_threads=${cpu}
#auto_increment_offset=1
#auto_increment_increment=2
innodb_lock_wait_timeout = 10
innodb_purge_threads = 18
innodb_purge_batch_size=3000

innodb_buffer_pool_dump_pct=80
innodb_max_dirty_pages_pct=75
innodb_buffer_pool_dump_at_shutdown=on
innodb_buffer_pool_load_at_startup=ON
innodb_buffer_pool_dump_now=ON
innodb_buffer_pool_filename=ON
#innodb_read_ahead_threshold=40
innodb_change_buffering=all
innodb_autoinc_lock_mode=2
secure-file-priv=''
innodb_print_all_deadlocks=1

[mysqldump]
quick
max_allowed_packet = 68M
[mysql]
no-auto-rehash
[mysqld_safe]
open-files-limit = 28192

EOF
fi
if [ ${role} == 'slave' ];then
cat > /etc/my.cnf <<-EOF
[mysqld]
server-id = 3
port = ${port}
basedir = ${base_dir}
datadir = ${data_dir} 
socket = ${base_dir}/mysql.sock 
pid-file=${data_dir}/mysql.pid
skip-external-locking 
skip_name_resolve
skip-slave-start
character-set-server = utf8mb4
collation-server = utf8mb4_general_ci
init_connect='SET NAMES utf8mb4'
max_connections = 1000
max_connect_errors = 1000
max_prepared_stmt_count=1048576
max_allowed_packet = 68M
open_files_limit=65535
tmp_table_size=512M
max_heap_table_size = 1G
sort_buffer_size = 1M
key_buffer_size=1M
join_buffer_size =2M
read_buffer_size=1M

binlog_cache_size = 12M
log_timestamps=SYSTEM
log-error=${data_dir}/mysqld.log
slow_query_log=ON
slow_query_log_file=${data_dir}/slow.log
long_query_time=1
innodb_temp_data_file_path = ibtmp1:12M:autoextend:max:5G

transaction_isolation=read-committed
log-bin=mysql-bin
max_binlog_size = 1G
binlog_row_image = full
log_bin_trust_function_creators=1
expire_logs_days=30
max_relay_log_size=1G
relay_log=mysql-relay
relay_log_recovery=1
master-info-repository = TABLE
relay-log-info-repository = TABLE
wait_timeout=9000
slave_skip_errors = all

sql_mode=NO_ENGINE_SUBSTITUTION,STRICT_TRANS_TABLES,NO_AUTO_CREATE_USER,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO
table_open_cache=2000
innodb_open_files=65500
binlog_format = row

report-host=${slave_ip}
report-port=${port}

innodb_flush_log_at_trx_commit = 2
sync_binlog = 1
innodb_buffer_pool_size = ${mem}${g}
innodb_file_per_table=1
innodb_data_file_path = ibdata1:12M;ibdata2:1G:autoextend
innodb_flush_method = O_DIRECT
innodb_log_file_size=8G
innodb_log_files_in_group=3
innodb_log_buffer_size = 12M
innodb_io_capacity=300		#SSD 3000
innodb_io_capacity_max=6000
innodb_lru_scan_depth = 2000
innodb_flush_neighbors = 1
innodb_sort_buffer_size=3108864
innodb_adaptive_flushing=1
innodb_read_io_threads=${cpu}
innodb_write_io_threads=${cpu}
#auto_increment_offset=1
#auto_increment_increment=2
innodb_lock_wait_timeout = 20
innodb_purge_threads = 18
innodb_purge_batch_size=3000

innodb_buffer_pool_dump_pct=80
innodb_max_dirty_pages_pct=75
innodb_buffer_pool_dump_at_shutdown=on
innodb_buffer_pool_load_at_startup=ON
innodb_buffer_pool_dump_now=ON
innodb_buffer_pool_filename=ON
#innodb_read_ahead_threshold=40
innodb_change_buffering=all
innodb_autoinc_lock_mode=2
secure-file-priv=''
innodb_print_all_deadlocks=1

[mysqldump]
quick
max_allowed_packet = 68M
[mysql]
no-auto-rehash
[mysqld_safe]
open-files-limit = 28192

EOF
fi
if [ ${role} == 'master' -a ${gtid} == 'on' ];then
sed -i "70i gtid_mode=ON" /etc/my.cnf
sed -i "71i log-slave-updates=ON" /etc/my.cnf
sed -i "72i enforce-gtid-consistency" /etc/my.cnf
fi

if [ ${role} == 'slave' -a ${gtid} == 'on' ];then
sed -i "70i slave-parallel-type=LOGICAL_CLOCK" /etc/my.cnf
sed -i "71i slave_preserve_commit_order=1" /etc/my.cnf
sed -i "72i slave-parallel-workers=8" /etc/my.cnf
sed -i "73i gtid_mode=ON" /etc/my.cnf
sed -i "74i enforce-gtid-consistency" /etc/my.cnf
#sed -i "75i log-slave-updates=ON" /etc/my.cnf
fi
if [ ${install_mgr} == "yes" ];then
sed -i '72i transaction_write_set_extraction=XXHASH64' /etc/my.cnf
sed -i '72i loose-group_replication_group_name="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"' /etc/my.cnf
sed -i '72i loose-group_replication_start_on_boot=off' /etc/my.cnf
sed -i '72i loose-group_replication_local_address ="'${ip}':24901"' /etc/my.cnf
sed -i '72i loose-group_replication_group_seeds= "'${group_ip}'"' /etc/my.cnf
sed -i '72i loose-group_replication_bootstrap_group=off' /etc/my.cnf
sed -i '72i #group_replication_auto_increment_increment=7' /etc/my.cnf
sed -i '72i loose-group_replication_single_primary_mode = on' /etc/my.cnf
sed -i '72i loose-group_replication_enforce_update_everywhere_checks = on' /etc/my.cnf
sed -i '72i loose-group_replication_compression_threshold=131072' /etc/my.cnf
sed -i '72i loose-group_replication_transaction_size_limit=20971520' /etc/my.cnf
sed -i '72i loose-group_replication_unreachable_majority_timeout=5' /etc/my.cnf
sed -i '72i slave-preserve-commit-order=1' /etc/my.cnf
sed -i '72i binlog-checksum=NONE' /etc/my.cnf
fi
cd ${base_dir}/bin
chown -R mysql:mysql ${base_dir}
if [ ${version} == "5.7" ];then
    ${base_dir}/bin/mysqld --initialize --user=${user} --basedir=${base_dir} --datadir=${data_dir}
fi
if [ ${version} == "5.6" ];then
    ${base_dir}/bin/mysql_install_db --user=${user} --basedir=${base_dir} --datadir=${data_dir}
fi
#--initialize-insecure
chkconfig --add mysqld
chkconfig mysqld on
${init_mysqld} start
#service mysqld start
init_passwd=$(cat ${data_dir}/mysqld.log  | grep "A temporary password" | awk -F " " '{print$11}')
cp -a ${base_dir}/bin/mysql /usr/bin
echo "mysql初始化密码为："${init_passwd}
mysql -uroot -p${init_passwd} -S ${base_dir}/mysql.sock
