#!/bin/bash

#Variável com o nome de usuario do OpenShift
read -p "Usuário do OpenShift: " USERNAMEOPENSHIFT

echo "Senha do OpenShift: "
#Variável com senha do usuario do OpenShift
read -s PWOPENSHIFT

read -p "Ambiente para build? (hml ou prd): " AMBIENTE_PROJECT
if [ "x$AMBIENTE_PROJECT" = "x" ]; then
    AMBIENTE_PROJECT="hml"
fi

read -p "Nome do pacote WAR (ROOT.war): " DEPLOY_ARTIFACT
if [ "x$DEPLOY_ARTIFACT" = "x" ]; then
    DEPLOY_ARTIFACT="ROOT.war"
fi

read -p "Nome da imagem/build: " NAME_IMAGE_BUILD
if [ "x$NAME_IMAGE_BUILD" = "x" ]; then
    echo "Execute novamente e infome o nome da imagem para executar o build"
    exit 1
fi

read -p "Confirma o build? (s/n): " confirm && [[ $confirm == [sS] || $confirm == [yY] ]] || exit 1

##########################################################################

# Preparando o binário para deploy
mv $DEPLOY_ARTIFACT ROOT.war
# Limpa a pasta deployments
rm -rf deployments/
# Cria estrutura de deploy
mkdir deployments/
mv ROOT.war deployments/

##########################################################################

oc login --username=$USERNAMEOPENSHIFT --password=$PWOPENSHIFT

oc project default

#Criando imagestream e tag para armazenar a imagem customizada
oc create istag $NAME_IMAGE_BUILD:$AMBIENTE_PROJECT -n openshift

#Obtendo a URL do Docker Registry do OpenShift
OCP_REGISTRY=`oc get route docker-registry -n default -o 'jsonpath={.spec.host}{"\n"}'`

#Efetuando login no Registry do OpenShift usando as credenciais do OpenShift
podman login -u $(oc whoami) -p $(oc whoami -t) ${OCP_REGISTRY} --tls-verify=false

#Executando build local da imagem customizada
podman build --tls-verify=false -t $OCP_REGISTRY/openshift/$NAME_IMAGE_BUILD:$AMBIENTE_PROJECT -f Dockerfile

#Enviando imagem local customizada para o Registry do OpenShift
podman push $OCP_REGISTRY/openshift/$NAME_IMAGE_BUILD:$AMBIENTE_PROJECT --tls-verify=false

#Adicionando meta informações sobre a imagem recém criada
oc annotate istag $NAME_IMAGE_BUILD:$AMBIENTE_PROJECT --overwrite tags='$NAME_IMAGE_BUILD, tomcat8, jboss-webservice30, openshift' version='$AMBIENTE_PROJECT' -n openshift
