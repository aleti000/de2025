#!/bin/bash
nbr=5 # количество мостов на этом стенде

function configure_network { #Настройка сетевых адаптеров для стенда
    echo "Создание сетевых устройств Proxmox"
    {
        for (( br=$(($first_isp + 10 * $i)); br <= $(($first_isp + 10 * $i + 5)); br++ ))
        do
            echo >> "/etc/network/interfaces"
            echo "auto vmbr$br" >> "/etc/network/interfaces"
            echo "iface vmbr$br inet manual" >> "/etc/network/interfaces"
            echo "	bridge-ports none" >> "/etc/network/interfaces"
            echo "	bridge-stp off" >> "/etc/network/interfaces"
            echo "	bridge-fd 0" >> "/etc/network/interfaces" 
            echo >> "/etc/network/interfaces"
            echo "Мост vmbr$br создан";
        done
    }&>/dev/null
     echo -e "\033[32m DONE \033[0m" 
}

function deploy_workplaces { #Цикл для развертывания множества стендов
    for (( i=1; i <= $workplace; i++ ))
    do
        configure_network
        deploy_workplace
    done
        echo "Перезагрузка сетевых параметров"
        sleep 1
        systemctl restart networking
        sleep 3
        echo -e "\033[32m DONE \033[0m"
    clear
    main
}

function deploy_workplace { #Развертка стенда
     echo "Создание машин для рабочего места $i из шаблонов"
    {   
        nvm=$(($first_isp + 10 * $i))
        nvm1=$(($first_isp + 10 * $i + 1))
        nvm2=$(($first_isp + 10 * $i + 2))
        nvm3=$(($first_isp + 10 * $i + 3))
        nvm4=$(($first_isp + 10 * $i + 4))
        nvm5=$(($first_isp + 10 * $i + 5))
        br1=vmbr$(($nvm))                               #Сеть ISP-HQ_RTR
        br2=vmbr$(($nvm + 1))                           #Сеть ISP-BR_RTR
        br3=vmbr$(($nvm + 2))                           #Сеть HQ_RTR-HQ_SRV
        br4=vmbr$(($nvm + 3))                           #Сеть HQ_RTR-HQ_CLI
        br5=vmbr$(($nvm + 4))                           #Сеть BR_RTR-BR_SRV
        #Клонирование шаблонов
        qm clone $isp $nvm --name "ISP"                  #создается СВЯЗАННЫЙ клон, если хотите создать не связанный добавьте ключ --full
        qm clone $router $nvm1 --name "HQ-RTR"                #создается СВЯЗАННЫЙ клон, если хотите создать не связанный добавьте ключ --full
        qm clone $router $nvm2 --name "BR-RTR"                #создается СВЯЗАННЫЙ клон, если хотите создать не связанный добавьте ключ --full
        qm clone $srv $nvm3 --name "HQ-SRV"              #создается СВЯЗАННЫЙ клон, если хотите создать не связанный добавьте ключ --full
        qm clone $srv $nvm4 --name "BR-SRV"              #создается СВЯЗАННЫЙ клон, если хотите создать не связанный добавьте ключ --full
        qm clone $cli $nvm5 --name "HQ-CLI"                 #создается СВЯЗАННЫЙ клон, если хотите создать не связанный добавьте ключ --full
        #Настраиваются апаратные части виртуальных машин
        qm set $nvm --ide2 none --net1 virtio,bridge=$br1 --net2 virtio,bridge=$br2 --tags DE_stand_user$nvm                                            #Настройка ISP
        qm set $nvm1 --net1 e1000,bridge=$br1 --net2 e1000,bridge=$br3  --net3 e1000,bridge=$br4 --tags DE_stand_user$nvm                #Настройка HQ-RTR
        qm set $nvm2 --net1 e1000,bridge=$br2 --net2 e1000,bridge=$br5 --tags DE_stand_user$nvm                                           #Настройка BR-RTR
        qm set $nvm3 --ide2 none --net0 virtio,bridge=$br3 --virtio1 local-lvm:1 --virtio2 local-lvm:1 --virtio3 local-lvm:1 --tags DE_stand_user$nvm   #Настройка HQ-SRV
        qm set $nvm4 --ide2 none --net0 virtio,bridge=$br5  --tags DE_stand_user$nvm                                                                    #Настройка BR-SRV
        qm set $nvm5 --ide2 none --net0 virtio,bridge=$br4 --tags DE_stand_user$nvm --cdrom none                                                        #Настройка HQ-CLI
    }&>/dev/null
    echo "Развертывание машин для рабочего места $i завершено"
    echo "Создание учетной записи"
    {
        pveum group add student-de --comment "users for DE"
        pveum user add user$nvm@pve --password P@ssw0rd --enable 1 --groups student-de #Создание пользователей для доступа к стенду
        pveum acl modify /vms/$nvm --roles PVEVMUser --users user$nvm@pve              #Выдача прав на доступ к стенду пользователям
        pveum acl modify /vms/$nvm1 --roles PVEVMUser --users user$nvm@pve             #Выдача прав на доступ к стенду пользователям
        pveum acl modify /vms/$nvm2 --roles PVEVMUser --users user$nvm@pve             #Выдача прав на доступ к стенду пользователям
        pveum acl modify /vms/$nvm3 --roles PVEVMUser --users user$nvm@pve             #Выдача прав на доступ к стенду пользователям
        pveum acl modify /vms/$nvm4 --roles PVEVMUser --users user$nvm@pve             #Выдача прав на доступ к стенду пользователям
        pveum acl modify /vms/$nvm5 --roles PVEVMUser --users user$nvm@pve             #Выдача прав на доступ к стенду пользователям
    }&>/dev/null
    echo -e "\033[32m DONE \033[0m" 
    echo "Создание рабочего места $i завершено"
}

function delete {
    max=$(($first_isp + $nbr))
    for (( j=$(($first_isp)); j <= $(($max)); j++ ))
    do
        echo "Удаление сетевых устройств Proxmox для стенда" 
        sed -i "/auto vmbr$j/,+6d" "/etc/network/interfaces"
        echo -e "\033[32m DONE \033[0m" 
    done
        echo "Удаление виртуальных машин стенда"
        {
            qm destroy $first_isp 
            qm destroy $(($first_isp + 1))
            qm destroy $(($first_isp + 2))
            qm destroy $(($first_isp + 3))
            qm destroy $(($first_isp + 4))
            qm destroy $(($first_isp + 5))
        }&>/dev/null
        echo -e "\033[32m DONE \033[0m" 
        echo "Удаление пользователя"
        {
            pveum user delete user$first_isp@pve
        }&>/dev/null
        echo -e "\033[32m DONE \033[0m" 
            clear 
            echo "Укажите номер следующего стенда для удаления: " 
            echo "Возврат в меню с перезагрузкой сети: 0 "
            read -p  "Выбор: " first_isp
                case $first_isp in
                 0)
                    systemctl restart networking
                    clear
                    main
                ;;
                *)
                    delete
                ;;
                esac
}

# shellcheck disable=SC2120


function main() {
    clear
    echo "+=========== Сделай выбор ============+"
    echo "|Развертка стендов из шаблонов: 1     |"
    echo "|Удаление стенда: 2                   |"
    echo "|Обновление параметров сети Proxmox: 3|"
    echo "+-------------------------------------+"
    read -p  "Выбор: " choice


    case $choice in
        1)
            read -p "Введите VMID шаблона HQ-SRV, BR-SRV: " srv
            read -p "Введите VMID шаблона HQ-CLI: " cli
            read -p "Введите VMID шаблона для машин HQ-RTR, BR-RTR: " router
            read -p "Введите VMID шаблона для машины ISP:" isp
            read -p "Введите количество стендов: " workplace
            read -p "Укажите VMID первой машины (-10): " first_isp
 #           read -p "Укажите примерное время включения ISP (в сек), важно для настройки ISP (для SSD - 30): " time
            deploy_workplaces
            #sleep 1
            #systemctl restart networking
        ;;
        2) 
            read -p "Укажите номер учетной запись стенда для удаления(для учетной записи user100 - нужно ввести 100) : " first_isp
            delete
        ;;
        3)
            systemctl restart networking
            main
        ;;
        *)
            echo "Нереализуемый выбор"
            exit 1
        ;;
    esac
}




main
