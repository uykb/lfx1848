clear
echo 安装基础工具包
sleep 2
yum install python-setuptools && easy_install pip -y
yum install git -y
clear
echo 从Git下载主文件
sleep 2
git clone -b manyuser https://github.com/tangwulin/shadowsocks.git
sleep 2
clear
echo 安装运行环境
sleep 2
cd shadowsocks
yum install python-devel -y
yum install libffi-devel -y -y
yum install openssl-devel -y
pip install -r requirements.txt
clear
echo 准备设置配置文件……
sleep 5
vi userapiconfig.py
sleep 2
clear
echo 安装Libsodium库
cd shadowsocks
yum install libsodium -y
##yum -y groupinstall "Development Tools" && wget https://github.com/jedisct1/libsodium/releases/download/1.0.10/libsodium-1.0.10.tar.gz && tar xf libsodium-1.0.10.tar.gz && cd libsodium-1.0.10 &&configure && make -j2 && make install && echo /usr/local/lib > /etc/ld.so.conf.d/usr_local_lib.conf &&ldconfig
sleep 2
clear
echo 关闭防火墙
#关掉这讨厌的防火墙！
systemctl stop firewalld.service
systemctl disable firewalld.service
clear
echo 设置开机自启和守护
#开机自启部分，原理有问题，有空再填坑
chmod +x /etc/rc.d/rc.local
echo "/root/shadowsocks/run.sh">>/etc/rc.d/rc.local
#5分钟启动一次节点，以防开机自启失败
echo "*/5 * * * * /root/shadowsocks/run.sh" >> /var/spool/cron/root
clear
echo 更换DNS
#更换DNS
rm -rf /etc/resolv.conf
touch /etc/resolv.conf
echo "nameserver 1.1.1.1">>/etc/resolv.conf
echo "nameserver 8.8.8.8">>/etc/resolv.conf
clear
echo 启动节点中
#最后启动一次
cd /root/shadowsocks/
bash run.sh
echo 完成！请根据输出判断结果！


