#!/bin/bash

# Set Builtin
# e => Exit 1 lorsqu'une commande échoue
# u => Exit 1 lorsqu'une variable non initialisée est utilisée
# o pipefail => Prends en compte le code erreur != 0 le plus à droite d'un pipe (en combinaison avec -e)
set -euo pipefail

# Création du répertoire de travail
TEMP_DIR=$(mktemp -d)

# En cas de sortie du programme (normale ou en erreur) on supprime le répertoire de travail
trap "rm -r ${TEMP_DIR} > /dev/null 2>&1" INT TERM EXIT

# Colorisation
INFO="\e[32m[INFO]\e[39m"
WARN="\e[33m[WARN]\e[39m"
CRIT="\e[31m[CRIT]\e[39m"
DEBUG="\e[35m[DEBUG]\e[39m"
ADD="\e[32m+\e[39m"
REM="\e[31m-\e[39m"

# Message d'erreur + code de retour 1
function error_exit
{
   echo -e "$CRIT Error: ${1:-"Erreur"}" 1>&2
   exit 1
}

# Permet de vérifier le contenu d'un war par rapport à un template
function check()
{
   # Contrôle de l'accessibilité des fichiers
   [ -r ${template} ] || error_exit "Le fichier ${template} n'existe pas ou n'est pas accessible en lecture. Abandon..."
   [ -r ${war_file} ] || error_exit "Le fichier ${war_file} n'existe pas ou n'est pas accessible en lecture. Abandon..."
   
   # Fichiers à traiter
   WAR_TPL=$(readlink -m ${template})
   WAR_FILE=$(readlink -m ${war_file})
   
   echo -e "$INFO Répertoire de travail: ${TEMP_DIR}"
   echo -e "$INFO Fichier source: ${WAR_FILE}"
   echo -e "$INFO Fichier template: ${WAR_TPL}"
   echo -e "$INFO Décompression du fichier WAR"
   
   # Extraction du WAR
   unzip ${WAR_FILE} -d ${TEMP_DIR} > /dev/null 2>&1 && echo -e "$INFO Décompression du fichier: OK" || error_exit "décompression du fichier ${WAR_FILE}"
   
   ##### Calcul des différences par rapport au template
   cd ${TEMP_DIR}
   
   # Contrôle de l'arborescence
   diffWar=$(diff <(find . -printf "%y%p\n") ${WAR_TPL} | egrep "^<|^>") || true
   if [[ -z "${diffWar}" ]]; then
   	echo -e "$INFO Le fichier WAR est conforme au template"
   else
        echo -e "$WARN L'arborescence du fichier WAR n'est pas conforme au template:"
   	diffFolder=$(echo "${diffWar}" | egrep "^(<|>)\sd") || true
   	diffFile=$(echo "${diffWar}" | egrep "^(<|>)\sf") || true
   	
   	# Contrôle des répertoires
   	if [[ -n ${diffFolder:-} ]]; then
   		diffFolder=${diffFolder//> d/$REM}
   		diffFolder=${diffFolder//< d/$ADD}	
   		echo -e "$CRIT Les répertoires suivants sont différents du template:"
   		echo -e "$diffFolder"
   	fi
   	
   	# Contrôle des fichiers
   	if [[ -n ${diffFile:-} ]]; then
   		diffFile=${diffFile//> f/$REM}
   		diffFile=${diffFile//< f/$ADD}	
   		echo -e "$WARN Les fichiers suivants sont différents du template:"
   		echo -e "$diffFile"
   	fi
   
   fi
}


# Permet de générer un template
function generate()
{
   WAR_TPL_OUT="${template}"
   if [ -a ${template} ]; then
	WAR_TPL_OUT=$(readlink -m ${template})
   	echo -e "$WARN Le fichier template ${WAR_TPL_OUT} existe déjà, voulez-vous l'écraser ? (o/n)"
	read -e REP
	case $REP in
	    O|o)
		echo -e "$INFO Le fichier sera écrasé"
	    ;;
	    N|n)
		echo -e "$INFO Sortie du programme"
		exit 1
	    ;;
            *)
		echo -e "$CRIT Mauvaise saisie"
		exit 1
	    ;;
	esac
   fi

   [ -r ${war_file} ] || error_exit "Le fichier ${war_file} n'existe pas ou n'est pas accessible en lecture. Abandon..."
   
   # On créé le fichier template si il n'existe pas
   touch ${WAR_TPL_OUT}
   WAR_TPL_OUT=$(readlink -m $WAR_TPL_OUT)
   
   # Fichiers à traiter
   WAR_FILE=$(readlink -m ${war_file})
   echo -e "$INFO Répertoire de travail: ${TEMP_DIR}"
   echo -e "$INFO Fichier source: ${WAR_FILE}"
   echo -e "$INFO Fichier template à générer: ${WAR_TPL_OUT}"
   echo -e "$INFO Décompression du fichier WAR"

   # Extraction du WAR
   unzip ${WAR_FILE} -d ${TEMP_DIR} > /dev/null 2>&1 && echo -e "$INFO Décompression du fichier: OK" || error_exit "décompression du fichier ${WAR_FILE}"
   
   # Génération du template
   cd ${TEMP_DIR}
   echo -e "$INFO Génération du template"
   find . -printf "%y%p\n" > ${WAR_TPL_OUT} 2>/dev/null && echo -e "$INFO Génération du template: OK" || error_exit "génération du template ${WAR_TPL_OUT}"
   
}

function help(){
    echo "check_war.sh - Permet de vérifier le contenu d'un fichier war par rapport à un template";
    echo "Usage: check_war.sh (-w|--war_file) string (-t|--template) string [(-h|--help)] [(-g|--generate)]";
    echo "Options:";
    echo "-h ou --help: Affiche cette aide.";
    echo "-w ou --war_file string: Fichier war à vérifier. Requis.";
    echo "-t ou --template string: Fichier template. Requis.";
    echo "-g ou --generate: Générer un template.";
    exit 1;
}
 
# Flags initialisés à 0
generate=0;
 
# Execute getopt
ARGS=$(getopt -o "hw:t:g" -l "help,war_file:,template:,generate" -n "check_war.sh" -- "$@");
 
# On affiche l'aide si des mauvais arguments ont étés passés
if [ $? -ne 0 ];
then
    help;
fi
 
eval set -- "$ARGS";
 
while true; do
    case "$1" in
        -h|--help)
            shift;
            help;
            ;;
        -w|--war_file)
            shift;
                    if [ -n "$1" ]; 
                    then
                        war_file="$1";
                        shift;
                    fi
            ;;
        -t|--template)
            shift;
                    if [ -n "$1" ]; 
                    then
                        template="$1";
                        shift;
                    fi
            ;;
        -g|--generate)
            shift;
                    generate="1";
            ;;
 
        --)
            shift;
            break;
            ;;
    esac
done
 
# On vérifie les arguments requis
if [ -z "${war_file:-}" ]
then
    echo -e "$CRIT L'argument war_file est manquant";
    help;
fi
 
if [ -z "${template:-}" ]
then
    echo -e "$CRIT L'argument template est manquant";
    help;
fi

# Main
[ ! "${generate}" == "1" ] && check || generate
