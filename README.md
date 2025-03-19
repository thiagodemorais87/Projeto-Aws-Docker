# Projeto-Aws-Docker

![projeto2-compass.png](https://vetores.org/d/compass-uol.svg)

# 📖 Índice


[🚀 1. Introdução](#introducao)

[🛠️ 2. Pré-requisitos](#pre-requisitos)

[☁️ 3. Criação da Rede AWS](#criacao-da-rede-aws)

[🛡️ 4. Configuração de Grupos de Segurança](#configuracao-de-grupos-de-seguranca)

[🏦 5. Preparando o Banco de Dados MySQL (RDS) ](#preparando-o-banco-de-dados-mysql-rds)

[📁 6. Configuração do EFS para Arquivos Estáticos](#configuracao-do-efs-para-arquivos-estaticos)

[⬆️ 7. Configuração do Auto Scaling Group](#configuracao-do-auto-scaling-group) 

[⚖️ 8. Configurando o Load Balancer](#configurando-o-load-balancer)

[🐳 9. Verificação da Configuração no Host EC2](#verificacao-da-configuracao-no-host-ec2)

[📊 10. Conclusão](#conclusao)



---

# 🚀 1. Introdução <a id="introducao"></a>

## 1.1 Objetivo do Projeto

Este projeto tem como foco implantar uma aplicação **WordPress** em uma infraestrutura de nuvem **AWS** com a utilização de **Docker** para conteinerização. 

O ambiente contará com um banco de dados **MySQL** gerenciado pelo **Amazon RDS**, um sistema de arquivos escalável através do **Amazon EFS** para armazenamento de arquivos estáticos, e um **Load Balancer** para distribuir o tráfego entre diferentes instâncias **EC2**.

O principal objetivo é criar uma infraestrutura que seja **escalável**, **altamente disponível**, e que suporte o crescimento do tráfego de forma automatizada. Tudo isso será orquestrado em uma **VPC** (Virtual Private Cloud), que permitirá a criação de subnets tanto públicas quanto privadas para melhor segurança e performance.

## 1.2 Visão Geral da Arquitetura
### **A arquitetura do projeto consiste nos seguintes componentes principais:**

- **Instâncias EC2:** Hospedam os containers **Docker** com a aplicação **WordPress**.
- **Amazon RDS (MySQL):** Banco de dados **MySQL** gerenciado pela **AWS**.
- **Amazon EFS:** Sistema de arquivos para armazenar os arquivos estáticos do **WordPress**.
- **Load Balancer:** Balanceando a carga, distribui o tráfego entre as instâncias **EC2** em diferentes **AZ.**
- **Auto Scaling Group:** Garante que a aplicação escale automaticamente com base na demanda.

---

# 🛠️ 2. Pré-requisitos <a id="pre-requisitos"></a>

### **Antes de iniciar o projeto, é necessário:**

- Uma **conta ativa** na **AWS**.
- Conhecimento básico de:
    - **Docker** para containerização.
    - **AWS** com foco em **EC2, RDS, EFS, e Load Balancer.**
    - **WordPress**.
- Acesso ao **AWS Management Console**.
- Um par de chaves **SSH** prontas para uso no acesso de **instâncias EC2** dentro do ambiente **aws.**
    - Caso não tenha chave **ssh** no ambiente **aws**, clicar em:
        - Recursos **EC2. > D**entro de Network e Security **> Key Pairs > Create New.**
            - Escolha um Nome**: `Project` (** recomendado **)**
            - Tipo**: RSA**
            - Formato**: .pem**
            - Clicar em criar que será criado e também baixado automaticamente, porém essa que foi feito o download não será utilizado.

---

# ☁️ 3. Criação da Rede AWS <a id="criacao-da-rede-aws"></a>

Nesta etapa, vamos preparar a infraestrutura na **AWS**, criando uma **VPC, sub-redes, gateways** e **tabelas de rotas** necessários para garantir um ambiente seguro e escalável para nossa aplicação.

## 3.1 Criação da VPC

- Crie uma **VPC** com um bloco CIDR adequado, por exemplo, `10.0.0.0/16`. Isso permite até 65.536 endereços IP privados.
- Nome Sugerido: `Project-VPC`

## 3.2 Criar um Internet Gateway (IGW)

Este gateway permitirá que a **subnet pública** (onde o CLB e o NAT Gateway estão localizados) tenha acesso à internet.

1. Dentro da **VPC**, clique em → **Internet Gateway**.
2. Crie um **Internet Gateway** e associe-o à **VPC**.

## 3.3 Configurar Subnets (Subnetworks)

### 3.31 **Subnet Pública** (para o CLB)

1. **Crie uma subnet pública em duas AZs** para garantir **alta disponibilidade** do CLB.
    - **AZ 1**: `us-east-1a` com bloco CIDR `10.0.1.0/24`
    - **AZ 2**: `us-east-1b` com bloco CIDR `10.0.3.0/24`
2. **Associar a Tabela de Rotas** com **Internet Gateway** (IGW):
    - Adicione uma rota para `0.0.0.0/0` com o **Internet Gateway** como destino.
    - **Associar a Tabela de Rotas** a essas duas subnets públicas.

### 3.3.2 **Subnets Privadas**

1. Crie **duas subnets privadas** em **duas AZs** (por exemplo, `us-east-1a` e `us-east-1b`), para garantir que as instâncias EC2 também estejam distribuídas entre as AZs e tenham alta disponibilidade.
    - **Subnet Privada 1a (us-east-1a)**: `10.0.2.0/24`
    - **Subnet Privada 1b (us-east-1b)**: `10.0.4.0/24`

1. Essas subnets serão usadas pelas **instâncias EC2** (por exemplo, WordPress).
2. **Não associe um Internet Gateway diretamente a essas subnets**. Em vez disso, use um **NAT Gateway** público (**3.4**) para permitir que as instâncias privadas acessem a internet de forma segura.

## 3.4 Criar duas NAT Gateway Público

Esse **NAT Gateway** permitirá que as instâncias nas **subnets privadas** acessem a internet de forma segura, sem expor seus endereços IP públicos.

1. Crie um **NAT Gateway** em **cada subnet pública**(`10.0.1.0/24` e `10.0.3.0/24`) para garantir redundância.
    - **Subnets: (`10.0.1.0/24` e `10.0.3.0/24`)**
    - **Tipo de conectividade: *public***
    - **Associar um novo Elastic IP (EIP)** em cada NAT Gateway (isso ocorre dentro do processo de criação do NAT Gateway, a não ser que queira fazer isso por fora e escolher um ip pré determinado).

## 3.5 Configurar Tabelas de Rotas

### 3.5.1 **Tabela de Rotas para a Subnet Pública** (para o CLB)

- Adicione uma rota para `0.0.0.0/0` com o **Internet Gateway** como destino.
- **Associe essa tabela de rotas às duas subnets públicas** (uma em cada AZ).
- **O CLB deve estar nas duas subnets públicas**, para garantir a **alta disponibilidade**.

### 3.5.2 **Tabela de Rotas para as 2 Subnets Privadas**

- Adicione uma rota para `0.0.0.0/0` com o **NAT Gateway** como destino.
    - **Importante**: O **NAT Gateway** pode ser redundante se você usar um em cada subnet pública.
- **Associe essas tabelas de rotas às subnets privadas**.

---

## 3.6 Subnet Associations

⚠️ Uma vez com as route tables criadas, ir em cada **route table > em “Subnet Associations”** e ajustar a paridade.

- **Para Route Table `P2-rtb-public-1a` > Associar a Subnet `P2-public-1a`**
- **Para Route Table `P2-rtb-public-1b` > Associar a Subnet `P2-public-1b`**
- **Para Route Table `P2-rtb-private-1a` > Associar a Subnet `P2-private-1a`**
- **Para Route Table `P2-rtb-private-1b` > Associar a Subnet `P2-private-1b`**

## 3.7 Resumo das Configurações das Subnets

| Subnet | AZ | Bloco CIDR | Uso Principal | Tabela de Rotas |
| --- | --- | --- | --- | --- |
| **Pública** | us-east-1a | `10.0.1.0/24` | Load Balancer e NAT Gateway | Rota para `0.0.0.0/0` via Internet Gateway |
| **Pública** | us-east-1b | `10.0.3.0/24` | Load Balancer e NAT Gateway | Rota para `0.0.0.0/0` via Internet Gateway |
| **Privada** | us-east-1a | `10.0.2.0/24` | Instâncias EC2 (WordPress) | Rota para `0.0.0.0/0` via NAT Gateway |
| **Privada** | us-east-1b | `10.0.4.0/24` | Instâncias EC2 (WordPress) | Rota para `0.0.0.0/0` via NAT Gateway |

---

# 🛡️ 4. Configuração de Grupos de Segurança <a id="configuracao-de-grupos-de-seguranca"></a>

## **4.1 Grupo de Segurança para o Load Balancer (CLB)**

- **Nome: `Project-CLB-SG`**

### **Regras de Entrada (Inbound)**:

- **Porta 80 (HTTP)**:
    - Tipo**: HTTP**
    - Protocolo**: TCP**
    - Intervalo de portas**: 80**
    - Origem**: `0.0.0.0/0` .**
- **Porta 443 (HTTPS)**:
    - Tipo**: HTTPS**
    - Protocolo**: TCP**
    - Intervalo de portas**: 443**
    - Origem**: `0.0.0.0/0`.**

### **Regras de Saída (Outbound)**:

- Permitir todo o tráfego de saída para as instâncias EC2 na porta 80 **(**editar posteriormente, logo depois do capítulo **4.2).**
- Selecionar Security Group das EC2 **“`Project-EC2-SG`”**. Porta **80.**
- Selecionar Security Group das EC2 **“`Project-EC2-SG`”**. Porta **443. (caso tenha certificado SSL)**

## **4.2 Grupo de Segurança para as Instâncias EC2**

- **Nome: `Project-EC2-SG`**

### **Regras de Entrada (Inbound)**:

- **Porta 80 (HTTP)**:
    - Tipo**: HTTP**
    - Protocolo**: TCP**
    - Intervalo de portas**: 80**
    - Origem**: ID do grupo de segurança do Load Balancer (`Project-CLB-SG`).**
- **Porta 22 (SSH):** ***¹***
    - Tipo**: SSH**
    - Protocolo**: TCP**
    - Intervalo **de portas: 22**
    - Origem**: ID do grupo de segurança das EC2 ( `Project-EC2-SG` )**
    
    - ***¹***  - Não é possível criar essa regra durante a criação do security group, após criação, clique em **Security Groups > `Project2-EC2-SG` > Regras de Entrada > Editar Regras de Entrada.**

### **Regras de Saída (Outbound)**:

- Permitir todo o tráfego de saída para a internet (ou restrinja conforme necessário).
    - Tipo**: Todo Trafego**

---

**Voltar para o Grupo de Segurança do Load Balancer e ajustar as regras de saída lá descritas no último item da lista.**

## **4.3 Grupo de Segurança para o RDS (MySQL) e EFS**

- **Nome**: `Project2-RDS&EFS-SG`

### **Regras de Entrada (Inbound)**:

- **Porta 3306 (MySQL)**:
    - Tipo**: MySQL/Aurora**
    - Protocolo**: TCP**
    - Intervalo de portas**: 3306**
    - Origem**: ID do grupo de segurança das instâncias EC2 (`Project-EC2-SG`).**
- **Porta 2049:**
    - Tipo**: NFS**
    - Protocolo**: TCP**
    - Intervalo de portas**: 2049**
    - Origem**: ID do grupo de segurança das instâncias EC2 (`Project-EC2-SG`).**

### **Regras de Saída (Outbound):**

- **Porta 2049:**
    - Tipo**: NFS**
    - Protocolo**: TCP**
    - Intervalo de portas: **2049**
    - Origem**: ID do grupo de segurança das instâncias EC2 (`Project-EC2-SG`).**

---

# 🏦 5. Preparando o Banco de Dados MySQL (RDS)  <a id="preparando-o-banco-de-dados-mysql-rds"></a>

## 5.1 Crie uma instância RDS MySQL na AWS.

### 5.1.1 Configurações usadas

- Escolha o database creation method**: standard create**
- Version**: MySQL 8.0.40**
    - Não marque (habilite) nada até **Templates**
- Template**: Free tier**
- DB instance identifier**: `project-db` —**  atualização do **endpoint** da instância RDS, apontando para o novo endereço de conexão.

### 5.1.2 Credential Settings <a id="credential-settings"></a>

- Master username**: `<user>` (escolha um nome de usuário, e anote-o)**
- Credentials management**: self managed**
- Master password**: `<password>` (escolha uma senha e anote-a)**

### 5.1.3 Configurações continuação

- Instance configuration **>** burstable classes **>**  **db.t3.micro**
- Storage: **5 GiB — gp2 (SSD)**
    - **❗Desabilitar storage auto scaling (em additional storage configuration)**
- Connectivity**: Não conectar a um recurso EC2**
- VPC criada para o projeto: **`Project-vpc`**
- DB Subnet Group**: Create new DB Subnet Group**
- Public access: **NÃO! — Falha de segurança grave!!**
- Security Group criada para o Database**: `Project-RDS&EFS-SG`**
- AZ**: No preference**

### 5.1.4 Additional Configuration

- Initial database name**: `wordpress`**
- Backup**: Desabilitado**
- Maintenance**: Desabilitado**
- Deletion protection**: Desabilitado**

## **5.2 ⚠️ ANOTE O Endpoint DO RDS❕** <a id="rds-5-2"></a>

**Isto é para conseguir configurar futuramente as credenciais do arquivo `docker-compose.yml`.** 

*Pode demorar um pouco, como foi demonstrado no exemplo da imagem abaixo, pois a aws necessita iniciar corretamente os parâmetros da instância, levando um determinado tempo.*

> **Caminho: RDS Console > Databases > Clique no DB criado > Connectivity & Security**

---

# 📁 6. Configuração do EFS para Arquivos Estáticos <a id="configuracao-do-efs-para-arquivos-estaticos"></a>

Neste capítulo, vamos configurar o Amazon Elastic File System (EFS) para armazenar arquivos estáticos com alta disponibilidade e segurança.

O EFS será acessado pelas instâncias EC2 na VPC via protocolo NFS (já configurado nos capítulos 3 e 4), garantindo o uso do sistema de arquivos de forma compartilhada e segura.

### 6.1 Criação do EFS no Console AWS

1. Acesse o **Console da AWS** e navegue até o serviço **EFS**.
2. Clique em **"Criar sistema de arquivos"**.
3. Escolha a **VPC** utilizada nos passos anteriores para garantir compatibilidade com os recursos existentes.
4. Sugestão de nome como **`Project-efs`**.
5. Clique em **Customize**

## 6.2 Configurações

### 6.2.1 Configurações do Sistema de Arquivos

1. Name**: `Project-efs`**
2. File system type**: Regional**
3. Lifecycle management**: Escolha conforme a necessidade.**
    1. Curtíssima Duração**: None — None — None**
4. Encryption**: Desabilitado**
5. Throughput mode**: Bursting**
6. Additional settings**:**
    1. Performance mode**: General Purpose**

### 6.2.2 Configurações de Rede

1. VPC**: `Project-vpc`**
2. Mount Targets**:**
    1. **us-east-1a > Private SubNet > `10.0.2.18` > `Project-RDS&EFS-SG`**
    2. **us-east-1b > Private SubNet > `10.0.4.36` > `Project-RDS&EFS-SG`**
    3. Use os **ips** que quiser e estejam disponíveis, esses foram para exemplificar.

### 6.2.3 Configurações de Policy

**Não precisa selecionar nada nesta etapa, deixe como está (padrão) e prossiga.** 

### 6.2.4 Review **> Agora, é só confirmar!** <a id="efs-ip"></a>

> **⚠️ ANOTE Os IPs DO EFS❕**
> 

**Caminho: EFS > File Systems > Clique no EFS criado > Network**

---

# ⬆️ 7. Configuração do Auto Scaling Group

- Escolha o nome do Auto Scaling Group, sugestão: **`Project-asg`**
- Clique em “**Create a launch template**” (caso não tenha o template, caso tenha, ignore a etapa **9.1**).

## 7.1 Configuração de Template <a id="configuracao-do-auto-scaling-group"></a>


1. Nome do Template (sugestão)**: `Project-template`** 
2. Descrição (sugestão)**: wordpress webservers**
3. Imagem: **`Amazon Linux 2023 AMI`**
4. Tipo**: t2.micro**
5. **Chave ssh**
6. Subnet: **não inclua no launch template**
7. Security Group**: `Project-EC2-SG`**
8. Storage: **Apenas o padrão da imagem**
9. Tags**: O que for necessário para as instâncias EC2**

### **Advanced Details:**

**(Ir até o fim onde tem o** user_data)

1. **Edite os seguintes parâmetros antes de salvar o script:**
    1. **Obs: Foi citado anteriormente para anotarem valores ao longo do processo descrito na documentação:**
        - **`rds-endpoint` —  *[**5.2 ⚠️ ANOTE O Endpoint DO RDS❕**](#rds-5-2)***
        - **`user` — *[5.1.2 Credential Settings](#credential-settings)***
        - **`password` — *[5.1.2 Credential Settings](#credential-settings)***
        - **Os 2 `EFS_IP` — *[**⚠️ ANOTE Os IPs DO EFS❕**](#efs-ip)***
   
1. **Launch Template**
2. **Voltando ao Auto Scaling Group:**
    1. Selecione a template criada **`Project-template`**
    2. **Next!**

## 7.2 Configuração do Auto Scaling Group

### **Passo 2: Instance Launch Options:**

- **VPC: `Project-vpc`**
- **AZ: `Project-private-1a` e `Project-private-1b`**
- **Distribuição de AZ: `Balanced best effort`**
- **NEXT!**

### **Passo 3: Em integração com outros serviços:**

- **No** (**Não**) Load Balancer
- **No** VPC Lattice service
- Zonal shift **desabilitado**
- Health Check **desabilitado**
- **NEXT!**

### **Passo 4: Configurar tamanho do grupo e escalabilidade:**

- **Desired Capacity: `2`**
- **Min: `2`**
- **Max: `3`**
- **Target Tracking Scaling Policy:**
    - **Nome: `Project-CPU-scaling-policy`**
    - Average **CPU** utilization
    - **Target:** 70 (70% ou mais de utilização cria +1 instância)
    - **WarmUp:** 300 (segundos)
- **Instance maintenance policy: `Terminate and Launch`**
- **Additional capacity settings: `None`**
- **Additional settings:** tudo desabilitado
- **NEXT!**

### **Passo 5: Notificações:**

- **Não precisa selecionar nada nesta etapa, deixe como está (padrão) e prossiga.**

### **Passo 6: Tags:**

- Escolha conforme achar necessário
- **NEXT!**

### **Passo 7: Review:**

- **CREATE AUTO SCALING GROUP!**

---

# ⚖️ 8. Configurando o Load Balancer <a id="configurando-o-load-balancer"></a>

## 8.1 Criação do Classic Load Balancer (CLB)

1. **No Console da AWS, em EC2**:
    - **Clique em: Load Balancers** > **Create Load Balancer**.
    - Escolha **Classic Load Balancer (previous generation)**.
2. **Configuração Básica e Rede:**
    - **Nome** (Sugestão): **`Project-clb`.**
    - Scheme**: `Internet-facing`**
    - VPC**: `Project-vpc`**
    - Subnets**: Escolha as 2 subnets públicas**
        - Evitar subnets privadas, caso queira reduzir custos com NAT Gateway.
    - Security Groups: **`Project-CLB-SG`**
3. **Listeners:**
    - Adicione listeners para:
        - **HTTP (Porta 80)**: Para tráfego não criptografado.
    - Adicione listeners para:
        - **HTTP (Porta 80)**: Para tráfego não criptografado.
4. **Health Checks:**
    - Defina o caminho do health check como: **`/wp-admin/install.php`**
    - Configure o intervalo para **30 segundos** e o limite de checagens para **2**.
5. **Associação ao ASG:**
    - Na seção **Instances**, **não adicione instâncias manualmente**.
    - O ASG já registrará automaticamente as instâncias no CLB.
6. **Tags (Opcional):**
    - Use se achar necessário.
7. **Attributes:**
    - ☑️ Enable cross-zone load balancing - Para garantir alta disponibilidade
    - ☑️ Enable connection draining -  Novas conexões não são direcionadas para a instância em remoção, mas as conexões ativas podem continuar até que sejam finalizadas.
    - Timeout: 300 segundos
8. **Review e Criação:**
    - Revise as configurações e crie o CLB.

### **Otimização de Custos no CLB**

- **Desligue o CLB** em ambientes de desenvolvimento/teste quando não estiver em uso.

## 8.2 Configuração do CLB no Auto Scaling Group

**No Console da AWS, em EC2**:

1. Clique em**:** **Auto Scaling Groups**
2. Selecione o **`Project-asg`** e clique em **Actions > Edit.**
3. Procure por “Load Balancing - *optional*”
4. Selecione **Classic Load Balancers > `Project-clb`**
5. Vá até o final e clique em **Update**



# 🐳 9. Verificação da Configuração no Host EC2 <a id="verificacao-da-configuracao-no-host-ec2"></a>

As instâncias EC2 foram criadas em subnets privadas, logo, você não terá acesso externo para se conectar via ssh de forma direta pelo seu terminal ou PuTTY. Mas isso não significa que não seja possível se conectar, existem algumas formas de fazer isso:

1. Criando um Bastion Host (servidor intermediário) para fazer essa conexão
2. Session Manager da AWS (ssm)
3. EC2 Serial Console
4. **Criando um Endpoint da Amazon** (parecido com Bastion Host) **—** Configuração escolhida para este capítulo dada a praticidade e facilidade.

## 9.1 Criando o Endpoint para se conectar as instâncias

Para criar um endpoint que te permita se conectar as instâncias **EC2,** deve ir em **VPC,** dentro da aba **PrivateLink and Lattice** e clicar em **> Endpoints > Create Endpoint.**

### Configurações do Endpoint:

- Name tag**: `Project-EC2-InstConnEndpoint`** (sugestão)
- Type**: EC2 Instance Connect Endpoint**
- VPC**: `Project-vpc`**
- Additional settings**: Não marcar nada**
- Security Groups**: `Project-EC2-SG`**
- Subnet**: escolher qualquer subnet PRIVADA  `P2-private-1a` ou  `1b`**
    
    > **OBS:** Mesmo um endpoint criado na 1b como nesse caso pode se conectar a instâncias em diferentes AZ, como a 1a, desde que a **Rede** e os **Security Groups** estejam configurados corretamente.
    > 
- **Criar Endpoint > Demora um pouco para configurar completamente.**

## 9.2 Usando o Endpoint para se conectar as instâncias

Para entrar na instância EC2 e verificar, editar, monitorar processos entre outras atividades, primeiro, em **EC2** clique em **Actions > Connect.** 

### E nas configurações de conexão:

- Connection Type**: Connect using EC2 Instance Connect Endpoint**
- EC2 Instance Connect Endpoint: **A opção que acabou de ser criada.**
- username**: ec2-user**
- Max tunnel duration (seconds)**: 3600**

Ex: EC2 Instance Conn Endpoint

## 9.3 Dentro da Instância EC2

### Sugestões de comandos e verificações:

- **Verificar se a instalação do Docker e do Docker Compose foram feitos da forma correta:**
    
    ```bash
    docker --version
    docker-compose --version
    ```
    
- **Verificar se a criação do .yml foi feita da maneira:**
    
    ```bash
    sudo cat /home/ec2-user/docker-compose.yml
    ```
    
- Verificar se as instâncias do Docker iniciaram corretamente
    
    ```bash
    docker ps # para veririficar as que estão em andamento
    docker ps -a # para veririficar as que estão paradas
    ```
    
- Verificar se o ambiente EFS está configurado corretamente e se os arquivos foram adicionados
    
    ```bash
    ls -lha /mnt/efs/wordpress_data/
    ```
    

# 🏁 10. Conclusão <a id="conclusao"></a>

## 10.1 Resumo do Projeto

Este projeto demonstrou a implementação de uma solução escalável e resiliente para o **WordPress** utilizando **Docker** na **AWS**. Ao integrar tecnologias como **RDS** para o banco de dados, **EFS** para armazenamento de arquivos e **Load Balancer** para balanceamento de carga, foi possível garantir uma infraestrutura robusta, com **alta disponibilidade** e preparada para o crescimento.

Além disso, com a utilização de práticas como o **Auto Scaling Group**, foi garantida uma resposta automatizada para variações na demanda, o que otimiza os custos e mantém a performance da aplicação estável.



