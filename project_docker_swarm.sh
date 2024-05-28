#!/bin/bash
# Variaveis a serem usadas
server_name="master"
current_server_name=$(hostname)
mng_swarm_IP="192.168.0.240"
nfs_path1=/nfs_script
script_path="$nfs_path1/script_worker.sh"

# Criação de diretório NFS e instalação de docker
mkdir /nfs_script
echo "Instalando o Docker......."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Condição para instalação em node gerenciador e node de servico
if [ "$current_server_name" == "$server_name" ]; then
    apt-get install nfs-server -y
    echo "$nfs_path1 *(rw,sync,subtree_check)" >> "/etc/exports"
    exportfs -ar

    # Captura o retorno do comando docker swarm init
    swarm_init_output=$(docker swarm init --advertise-addr "$mng_swarm_IP")

    # Captura a linha completa que contém o token
    join_command=$(echo "$swarm_init_output" | grep 'docker swarm join --token')

    # Extrai o token da linha capturada
    token=$(echo "$join_command" | awk '{print $5}')
    # Extrai o token da linha capturada
    echo "#!/bin/bash" > $script_path
    echo "docker swarm join --token "$token" "$mng_swarm_IP":2377" >> $script_path
    sudo chmod +x $script_path

    # Verifica se o token foi capturado corretamente
    if [ -z "$join_command" ]; then
    echo "Erro ao capturar o token. Verifique o retorno do comando docker swarm init."
    exit 1
    fi

else
    apt install nfs-common -y
    showmount -e $mng_swarm_IP
    sudo mount $mng_swarm_IP:$nfs_path1 $nfs_path1
    sudo "$script_path"
fi