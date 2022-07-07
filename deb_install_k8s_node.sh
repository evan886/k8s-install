#!/bin/bash

# 注意 dns 记得为8.8.4.4;  kubelet  几个注意改为你要的版本
# 谢谢 https://juejin.cn/post/7055180924681453582
# Kubernetes部署环境要求：
#（1）一台或多台机器，操作系统debian 11.x-86_x64
#（2）硬件配置：内存2GB或2G+，CPU 2核或CPU 2核+；
#（3）集群内各个机器之间能相互通信；
#（4）集群内各个机器可以访问外网，需要拉取镜像；
#（5）禁止swap分区；

# 安装步骤
#1. 安装docker
#1.1 如果没有安装docker，则安装docker。会附带安装一个docker-compose 可能不成功不过不影响我们 K8S
#2. 安装k8s
#2.1 初始化环境
#2.2 添加安装源
#2.3 安装kubelet、kubectl、kubeadmin
#2.4 安装master
#2.5 安装网络插件

#node 的要手要 在 是否安装k8s？默认为：no. Enter [yes/no]：no
# 后面的全要手工  或者 找init的func注释掉就行了

set -e

# 安装日志
install_log=/var/log/install_k8s.log
tm=$(date +'%Y%m%d %T')

# 日志颜色
COLOR_G="\x1b[0;32m"  # green
RESET="\x1b[0m"

function info(){
    echo -e "${COLOR_G}[$tm] [Info] ${1}${RESET}"
}

function run_cmd(){
  sh -c "$1 | $(tee -a "$install_log")"
}

function run_function(){
  $1 | tee -a "$install_log"
}

function install_docker(){
  info "1.使用脚本自动安装docker..."
  curl -sSL https://get.daocloud.io/docker | sh

  info "2.启动 Docker CE..."
  sudo systemctl enable docker
  sudo systemctl start docker

  info "3.添加镜像加速器..."
  if [ ! -f "/etc/docker/daemon.json" ];then
    touch /etc/docker/daemon.json
  fi
  cat <<EOF > /etc/docker/daemon.json
{
  "registry-mirrors": [
    "https://5ajk0rns.mirror.aliyuncs.com"
    ]
}
EOF

  info "4.重新启动服务..."
  sudo systemctl daemon-reload
  sudo systemctl restart docker

  info "5.测试 Docker 是否安装正确..."
  docker run hello-world

  info "6.检测..."
  docker info

  read -p "是否安装docker-compose？默认为 no. Enter [yes/no]：" is_compose
  if [[ "$is_compose" == 'yes' ]];then
    info "7.安装docker-compose"
    #sudo curl -L "http://linuxsa.org/docker-compose-2.6.1" -o /usr/local/bin/docker-compose
    sudo curl -L "https://github.com/docker/compose/releases/download/2.6.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/sbin/docker-compose
    sudo chmod a+x /usr/sbin/docker-compose



    # 8.验证是否安装成功
    info "8.验证docker-compose是否安装成功..."
    docker-compose -v
  fi
}

function install_k8s() {
    info "初始化k8s部署环境..."
    init_env

    info "添加k8s安装源..."
    add_aliyun_repo

    info "安装kubelet kubeadmin kubectl..."
    install_kubelet_kubeadmin_kubectl

    info "安装kubernetes master..."
    apt  -y install net-tools
    if [[ ! "$(ps aux | grep 'kubernetes' | grep -v 'grep')" ]];then
       info 'It is node '
      #kubeadmin_init
    else
      info "kubernetes master已经安装..."
    fi

    info "安装网络插件flannel..."
    
    #install_flannel

    #info "去污点...,去污点就是在master上也可以被调度pod]" #这个我注释掉了
    #kubectl taint nodes --all node-role.kubernetes.io/master-
}

# 初始化部署环境
function init_env() {
  info "关闭防火墙"
  #systemctl stop firewalld
  #systemctl disable firewalld

  info "关闭selinux"
  #sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/g' /etc/selinux/config
  #source /etc/selinux/config

  info "关闭swap（k8s禁止虚拟内存以提高性能）"
  swapoff -a
  sed -i '/swap/s/^\(.*\)$/#\1/g' /etc/fstab

  info "设置网桥参数"
  cat <<-EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
  sysctl --system  #生效
  sysctl -w net.ipv4.ip_forward=1

  info "时间同步"
  apt  install ntpdate  -y
  ntpdate time.windows.com
}

# 添加aliyun安装源

 #curl -s https://mirrors.huaweicloud.com/kubernetes/apt/doc/apt-key.gpg | sudo apt-key add -

function add_aliyun_repo() {
  apt  install  gnupg -y
 curl -s https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | sudo apt-key add -

  cat > /etc/apt/sources.list.d/kubernetes.list <<- EOF
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF
}

function add_aliyun_YUMrepo() {
  cat > /etc/yum.repos.d/kubernetes.repo <<- EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
}

# 我应该 要改为  1-20版本 也行  不过 tke 有 1.18.4    1.20.6   1.24.0-00 1.22.11-00
function install_kubelet_kubeadmin_kubectl() {
    sudo  apt update 
    Kver=1.22.11-00
    #Kver=1.24.2-00
    sudo apt install kubelet=${Kver} kubeadm=${Kver} kubectl=${Kver}  -y
    #sudo apt install kubelet=1.24.0-00 kubeadm=1.24.0-00 kubectl=1.24.0-00 -y
    #sudo apt install kubelet=1.20.6-00 kubeadm=1.20.6-00 kubectl=1.20.6-00 -y
    systemctl enable kubelet.service

    info "确认kubelet kubeadmin kubectl是否安装成功"
    apt list  --installed | grep kubelet
    apt list  --installed | grep kubeadm
    apt list  --installed | grep kubectl
    kubelet --version
}

function kubeadmin_init() {
  sleep 1
  read -p "请输入master ip地址：" ip
  # 1.20 , 1.22.11是成功的 
  mKver=v1.22.11
  kubeadm init --apiserver-advertise-address="${ip}" --image-repository registry.aliyuncs.com/google_containers --kubernetes-version $mKver --service-cidr=10.96.0.0/12 --pod-network-cidr=10.244.0.0/16
  mkdir -p "$HOME"/.kube
  sudo cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config
  sudo chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config
}

function install_flannel() {
  apt -y install wget
  wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
  kubectl apply -f kube-flannel.yml
}
echo "OS init"

function pre_init() {
  cat > /etc/resolv.conf <<- EOF
nameserver 8.8.4.4
nameserver 223.5.5.5
EOF

apt update 
apt install -y apt-transport-https curl wget gnupg2  software-properties-common  net-tools procps  rsync  w3m  vim  build-essential gcc  dnsutils tmux   sudo lsb-release  iotop 
}

pre_init

# 安装docker
read -p "是否安装docker？默认为：no. Enter [yes/no]：" is_docker
if [[ "$is_docker" == 'yes' ]];then
  run_function "install_docker"
fi

# 安装k8s
read -p "是否安装k8s？默认为：no. Enter [yes/no]：" is_k8s
if [[ "$is_k8s" == 'yes' ]];then
  run_function "install_k8s"
fi
