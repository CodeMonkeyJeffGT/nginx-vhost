#/bin/bash

basepath=$(cd `dirname $0`; pwd)"/"
cons=""
loc=""
hosts=""
base="server { listen 80; server_name blog.com; location / { root html/Lar-Blog/public; index index.html index.htm index.php; try_files \$uri \$uri/ /index.php?\$query_string; } error_page 500 502 503 504 /50x.html; location = /50x.html { root html/Lar-Blog/public; } location ~ \.php$ { root html/Lar-Blog/public; fastcgi_pass 127.0.0.1:9000; fastcgi_index index.php; fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name; include fastcgi_params; } }"
info=()
hostList=()

function assure()
{
    msg=$1
    echo -n $msg"?(y/n)："
    read assure
    if [ ! $assure ] || [ $assure != "y" ] ; then
        exit 1
    fi
}

function init()
{
    cons=$1
    loc=$2
    hosts="/etc/hosts"
    echo "配置文件夹："$cons
    echo "web根目录："$loc
    echo -e $cons"\n"$loc"\n"$hosts > $basepath'vhost-auto.conf'
    echo "创建配置文件完毕"
}

function drop()
{
    rm $basepath"vhost-auto.conf"
    echo "配置已清空"
}

function getConf()
{
    conf=(`cat $basepath"vhost-auto.conf"`)
    cons=${conf[0]}
    loc=${conf[1]}
    hosts=${conf[2]}
    conf=""
}

function getInfo()
{
    name=$1
    if [ ! -e $cons"/"$name ] ; then
        echo "文件"$name"不存在"
        exit 1
    fi
    base=`cat $cons"/"$name`
    base=($base)
    info[0]=${name/.conf/}
    fileloc=${base[10]}
    fileloc=${fileloc/;/}
    info[1]=${fileloc/html\//}
    filedomain=${base[5]}
    info[2]=${filedomain/;/}
    fileport=${base[3]}
    info[3]=${fileport/;/}
}

function changeRoot()
{
    root=$1
    if [ ${root:0:1} != "/" ] ; then
        root="html/"$root
    fi
    base[10]=$root";"
    base[31]=$root";"
    base[38]=$root";"
}

function changeDomain()
{
    domain=$1
    if [ ${info[2]} ] ; then
        deleteDomain ${info[2]}
    fi
    if [ $domain ] ; then
        addDomain $domain
    fi
    base[5]=$domain";"
}

function changePort()
{
    port=$1
    base[3]=$port";"
}

function buildStr()
{
    base=${base[@]}
    base=${base//";"/";\n"}
    base=${base//"{"/"{\n"}
    base=${base//"}"/"}\n"}
}

function listDomain()
{
    hostIndex=0
    hostStr=""
    while read line
    do
        if [ "${line:0:1}" == '#' ] ; then
            hostStr=$hostStr$line"\n"
            continue
        fi
        lineArr=($line)
        if [ "${lineArr[0]}" != '127.0.0.1' ] ; then
            hostStr=$hostStr$line"\n"
            continue
        fi
        hostList[$hostIndex]=${lineArr[1]}
        let hostIndex++
    done < $hosts
    hostStr=${hostStr:0:`expr ${#hostStr} - 2`}
}

function addDomain()
{
    domain=$1
    flag=1
    for ((i=0; i<${#hostList[@]}; i++)) {
        if [ ${hostList[$i]} == $domain ] ; then
            hostList[$i]=${hostList[${#hostList[@]}]}
            flag=0
            break
        fi
    }
    if [ $flag == 1 ] ; then
        hostList[${#hostList[@]}]=$domain
    fi
}

function deleteDomain()
{
    deleted=$1
    for ((i=0; i<${#hostList[@]}; i++)) {
        if [ ${hostList[$i]} == $deleted ] ; then
            hostList[$i]=${hostList[${#hostList[@]}]}
            unset hostList[${#hostList[@]}]
        fi
    }
}

function saveDomain()
{
    for domain in ${hostList[@]}
    do
        hostStr="127.0.0.1 "$domain"\n"$hostStr
    done
    echo -e $hostStr > $cons"/hosts-tmp"
    sudo mv $cons"/hosts-tmp" $hosts
}

function new()
{
    listDomain
    name=$1
    root=$2
    domain=$3
    port=$4
    base=($base)
    changeRoot $root
    changeDomain $domain
    changePort $port
    buildStr
    echo -e $base > $cons"/"$name".conf"
    saveDomain
}

function delete()
{
    listDomain
    name=$1".conf"
    getInfo $name
    echo -e ${info[0]}"\t"${info[1]}"\t"${info[2]}"\t"${info[3]}
    assure "确认删除"
    `rm $cons"/"$name`
    changeDomain
    saveDomain
}

function clear()
{
    listDomain
    assure "确认清空所有虚拟域名？此操作不可恢复"
    files=$cons"/*.conf"
    files=($files)
    if [ $cons"/*.conf" == $files ] ; then
        echo "配置已清空"
        exit 0
    fi
    for thisfile in ${files[@]} 
    do
        filename=${thisfile/$cons/}
        getInfo ${filename:1}
        changeDomain
        echo "rm "$thisfile
        rm $thisfile
    done
    saveDomain
    echo "配置已清空"
}

function list()
{
    list=(`ls $cons | grep .conf$`)
    printf "%-10s %-30s %-15s %s\n" "-name-" "-root-" "-domain-" "-port-"
    for thisfile in ${list[@]}
    do
        getInfo $thisfile
        printf "%-10s %-30s %-15s %s\n" ${info[0]} ${info[1]} ${info[2]} ${info[3]}
    done
}

function back()
{
    list=(`ls $cons | grep .conf$`)
    for thisfile in ${list[@]}
    do
        cp $cons"/"$thisfile $cons"/"$thisfile".back"
        echo "backup "$cons"/"$thisfile" to "$cons"/"$thisfile".back"
    done
    echo "备份完成"
}

function restore()
{
    listDomain
    assure "此操作不可逆,确认还原所有虚拟域名"
    list=(`ls $cons | grep .conf.back$`)
    for thisfile in ${list[@]}
    do
        getInfo $thisfile
        new ${info[0]} ${info[1]} ${info[2]} ${info[3]}
    done
    saveDomain
    echo "还原完成"
}

function croot()
{
    name=$1
    name=$name".conf"
    root=$2
    getInfo $name
    changeRoot $root
    buildStr
    echo -e $base > $cons"/"$name
}

function cdomain()
{
    listDomain
    name=$1
    name=$name".conf"
    domain=$2
    getInfo $name
    changeDomain $domain
    saveDomain
    buildStr
    echo -e $base > $cons"/"$name
}

function cport()
{
    name=$1
    name=$name".conf"
    port=$2
    getInfo $name
    changePort $port
    buildStr
    echo -e $base > $cons"/"$name
}

function menu()
{
    echo "usage vhost init                              初始化配置"
    echo "      vhost drop                              清空配置（不影响已配置的虚拟域名）"
    echo "      vhost list                              查看全部虚拟域名"
    echo "      vhost new name root domain [port=80]    新建虚拟域名"
    echo "      vhost delete name                       删除虚拟域名"
    echo "      vhost list                              显示当前虚拟域名列表"
    echo "      vhost clear                             清空所有虚拟域名（不可恢复，谨慎使用）"
    echo "      vhost croot name                        修改路径"
    echo "      vhost cdomain name                      修改域名"
    echo "      vhost cport name                        修改端口"
    echo "      vhost back                              备份全部虚拟域名（全部备份为原文件.back，不会被清理)"
    echo "      vhost restore                           还原全部虚拟域名（不可逆)"
}

opt=$1
if [ ! -e $basepath"vhost-auto.conf" ] ; then
    if [ ! $opt ] || [ $opt != "init" ] ; then
        echo -e "请先初始化:\n    vhost init [nginx路径] [自动加载相对路径]"
        exit 5
    else
        loc=$2
        cons=$3
        if [ ! $loc ] ; then
            echo -n "请输入nginx自动加载文件夹路径（默认为/usr/local/etc/nginx/servers）："
            read loc
            if [ ! $loc ]; then
                loc="/usr/local/etc/nginx/servers"
            fi
        fi
        if [ ! $cons ] ; then
            echo -n "web根路径（默认为/usr/local/var/www）："
            read cons
            if [ ! $cons ]; then
                cons="/usr/local/var/www"
            fi
        fi
        init $loc $cons
        exit 0
    fi
fi

getConf
case $1 in
    "init")
        echo -e "配置文件已存在，如需重新配置请输入：\n    vhost drop"
        ;;
        "drop")
        drop
        ;;
    "new")
        name=$2
        root=$3
        domain=$4
        port=$5
        if [ $name ] && [ -e $cons"/"$name".conf" ] ; then
            echo "名称"$name".conf被占用，请更换"
            name=""
        fi
        while [ ! $name ]
        do
            echo -n "请输入名称："
            read name
            if [ $name ] && [ -e $cons"/"$name".conf" ] ; then
                echo "名称"$name".conf被占用，请更换"
                name=""
            fi
        done
        while [ ! $root ]
        do
            echo -n "请输入项目路径："
            read root
        done
        while [ ! $domain ]
        do
            echo -n "请输入域名："
            read domain
        done
        if [ ! $port ] ; then
            port=80
        fi
        new $name $root $domain $port
        ;;
    "croot")
        name=$2
        root=$3
        while [ ! $name ]
        do
            echo -n "请输入名称："
            read name
        done
        while [ ! $root ]
        do
            echo -n "请输入root："
            read root
        done
        croot $name $root
        ;;
    "cdomain")
        name=$2
        domain=$3
        while [ ! $name ]
        do
            echo -n "请输入名称："
            read name
        done
        while [ ! $domain ]
        do
            echo -n "请输入domain："
            read domain
        done
        cdomain $name $domain
        ;;
    "cport")
        name=$2
        port=$3
        while [ ! $name ]
        do
            echo -n "请输入名称："
            read name
        done
        while [ ! $port ]
        do
            echo -n "请输入port："
            read port
        done
        cport $name $port
        ;;
    "delete")
        name=$2
        delete $name
        ;;
    "clear")
        clear
        ;;
    "list")
        list
        ;;
    "back")
        back
        ;;
    "restore")
        restore
        ;;
    *)
        menu
        ;;
esac
