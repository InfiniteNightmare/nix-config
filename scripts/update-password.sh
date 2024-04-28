#!/usr/bin/env bash

# 定义数据库路径和查询关键字
DATABASE_PATH="/home/shb/Onedrive/KeePass/daily-server-accounts.kdbx"
DATABASE_KEY="gaoyjDBL775185*"

# 遍历数据库中的条目
declare -a SERVER_IPS=()
while IFS= read -r IP
do
    SERVER_IPS+=("$IP")
done <<< "$(echo "$DATABASE_KEY" | keepassxc-cli ls "$DATABASE_PATH")"

for IP in ${SERVER_IPS[*]}
do
    # 解析出服务器信息
    # 默认用户是root
    USERNAME="root"
    echo "$IP"
    PORT=$(echo "$DATABASE_KEY" | keepassxc-cli show -a port "$DATABASE_PATH" "$IP")
    # 获取旧密码
    PASSWORD=$(echo "$DATABASE_KEY" | keepassxc-cli show -s -a Password "$DATABASE_PATH" "$IP")

    # 使用keepassxc-cli生成新密码
    NEW_PASSWORD=$(keepassxc-cli generate -L 24 -l -U -n -s --every-group)

    # 使用SSH修改远程服务器密码（这里假设使用密钥验证登录，否则需要处理密码交互问题）
    # 使用 sshpass 带密码登陆
    # 使用 printf 格式化输出的同时不对NEW_PASSWORD转义
    printf '%s\n%s' "$NEW_PASSWORD" "$NEW_PASSWORD" | sshpass -p "$PASSWORD" ssh -p "$PORT" "$USERNAME"@"$IP" passwd

    # 尝试用新密码登陆
    # 如果成功，则将新密码更新到数据库中
    if [ $(sshpass -p "$NEW_PASSWORD" ssh -o PreferredAuthentications=password -p "$PORT" "$USERNAME"@"$IP" echo "OK") = "OK" ]
    then
        echo -e "$DATABASE_KEY\n$NEW_PASSWORD" | keepassxc-cli edit "$DATABASE_PATH" "$IP" -p
    fi
done
