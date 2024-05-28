#!/bin/bash
# Variaveis a serem usadas
server_name="master"
current_server_name=$(hostname)
mng_swarm_IP="192.168.0.240"
nfs_path1=/nfs_script
nfs_path2=/var/lib/docker/volumes/app/_data
script_path="$nfs_path1/script_worker.sh"
site_path="$nfs_path2/index.html"
clone_site_path="/home/vagrant/cluster_swarm_with_vagrant/index.html"

# Criação de diretório NFS e instalação de docker
mkdir /nfs_script
echo "Instalando o Docker......."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Condição para instalação em node gerenciador e node de servico
if [ "$current_server_name" == "$server_name" ]; then
    apt-get install nfs-server -y
    docker volume create app
    git clone https://github.com/EFranca88/cluster_swarm_with_vagrant.git
    cp $clone_site_path $nfs_path2
    echo "$nfs_path1 *(rw,sync,subtree_check)" >> "/etc/exports"
    echo "$nfs_path2 *(rw,sync,subtree_check)" >> "/etc/exports"
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


    # Função que cria o Serviço Docker 'meu-app' após 5 minutos
    service_create() {
    # Aguardar 5 minutos (1m=60 seg, 2m=120 seg, 3m=180 seg, 4m=240 seg, 5m=300 seg)
    sleep 300
    # Criar o serviço
    docker service create --name meu-app --replicas 7 -dt -p 80:80 --mount type=volume,src=app,dst=/usr/local/apache2/htdocs/ httpd
    # Verificar se o comando foi bem sucedido
    if [ $? -eq 0 ]; then
        echo "Serviço Docker 'meu-app' criado com sucesso."
    else
        echo "Falha ao criar o serviço Docker 'meu-app'."
    fi
    }

    # Executa a função em segundo plano
    service_create &

    # Mensagem para indicar que o script principal terminou
    echo "O comando para criar o volume Docker será executado em segundo plano após 5 minutos."

else
    apt install nfs-common -y
    showmount -e $mng_swarm_IP
    sudo mount $mng_swarm_IP:$nfs_path1 $nfs_path1
    sudo "$script_path"
fi