# TODO: 
# docker 일 경우
# nginx 일 경우 

#!/bin/bash

Color_Off='\033[0m'

BBlue='\033[1;34m'
BGreen='\033[1;32m'
BYellow='\033[1;33m'
BRed='\033[1;31m'

INFO=$BBlue
SUCCESS=$BGreen
WARN=$BYellow
DANGER=$BRed

# 루트 권한 확인
if [ "$(id -u)" -ne 0 ]; then
    printf "${DANGER}루트 권한이 필요합니다.${Color_Off}\n"
    exit 1
fi

# 패키지 설치 함수
install_idn() {
    if [ -x "$(command -v yum)" ]; then
        # CentOS/RHEL 계열
        if ! rpm -q libidn >/dev/null 2>&1; then
            printf "${INFO}libidn 패키지를 설치합니다.${Color_Off}\n"
            yum install -y libidn
            printf "${SUCCESS}libidn 패키지 설치 완료.${Color_Off}\n"
        else
            printf "${INFO}libidn 패키지가 이미 설치되어 있습니다.${Color_Off}\n"
        fi
    elif [ -x "$(command -v apt-get)" ]; then
        # Debian/Ubuntu 계열
        if ! which idn2; then
            printf "${INFO}idn2 패키지를 설치합니다.${Color_Off}\n"
            apt-get update
            apt-get install -y idn2
            printf "${SUCCESS}idn2 패키지 설치 완료.${Color_Off}\n"
        else
            printf "${INFO}idn2 패키지가 이미 설치되어 있습니다.${Color_Off}\n"
        fi
    else
        printf "${DANGER}지원하지 않는 패키지 매니저입니다.${Color_Off}\n"
        exit 1
    fi
}

# 입력받은 도메인이 한글인지 확인하고 퓨니코드로 변환
check_korean_in_domain() {
    local domain="$1"
    if echo "$domain" | grep -P '[\p{Hangul}]' >/dev/null; then
       install_idn
    fi
}

# idn 패키지 확인 및 설치
check_korean_in_domain

# idn 명령어 선택 함수 (운영체제에 따라 다름)
get_idn_command() {
    if [ -x "$(command -v yum)" ]; then
        echo "idn"  # CentOS는 idn 사용
    elif [ -x "$(command -v apt-get)" ]; then
        echo "idn2" # Ubuntu는 idn2 사용
    else
        printf "${DANGER}지원하지 않는 운영체제입니다.${Color_Off}\n"
        exit 1
    fi
}

# 입력받은 도메인이 한글인지 확인하고 퓨니코드로 변환
convert_to_punycode() {
    local domain="$1"
    local idn_command
    idn_command=$(get_idn_command)

    if echo "$domain" | grep -P '[\p{Hangul}]' >/dev/null; then
        # 한글이 포함된 도메인일 경우 idn 또는 idn2 명령어로 퓨니코드 변환
        "$idn_command" --quiet "$domain"
    else
        # 한글이 포함되지 않은 도메인일 경우 그대로 반환
        echo "$domain"
    fi
}


# 검색하려는 도메인을 입력받음
search_domain=$1
printf "${INFO}입력받은 도메인: ${Color_Off}$search_domain\n"

# 도메인을 퓨니코드로 변환
search_domain_punycode=$(convert_to_punycode "$search_domain")
printf "${INFO}검색 할 도메인: ${SUCCESS}$search_domain_punycode${Color_Off}\n"

# 웹서버 확인
web_server=$( ps -e | grep -E 'nginx|apache|httpd' | head -n 1 | awk '{print $4}')

# if [[ -z "$web_server" ]]; then
#     printf "${DANGER}웹서버를 찾을 수 없습니다.${Color_Off}\n"
#     exit 1
# fi

# # 웹서버가 로컬에 설치되어있는지 확인
# isLocal=$(which $web_server)

# 실행 중인 웹 서버가 없는 경우 경고 메시지만 출력하고 진행
if [[ -z "$web_server" ]]; then
    printf "${DANGER}웹서버가 실행 중이지 않습니다.${Color_Off}\n"
else
    printf "${INFO}실행 중인 웹서버:${Color_Off} $web_server\n"
fi

# 로컬 설치 여부 확인 (Apache 또는 Nginx)
isLocal=$(which $web_server 2>/dev/null)

# Apache 및 Nginx 서버 설정 파일이 있을 수 있는 경로 리스트
HTTPD_TARGETS="/etc/httpd /usr/pkg/etc/httpd /etc/init.d/httpd"

APACHE_TARGETS="/etc/apache /etc/apache2 /opt/apache \
    /usr/local/apache /usr/local/apache2 \
    /usr/local/etc/apache /usr/local/etc/apache2 /usr/local/etc/apache22 \
    /etc/sysconfig/apache2 /usr/local/etc/apache24"

NGINX_TARGETS="/etc/nginx /usr/local/etc/nginx"

# 로컬에서 찾을 수 없을 경우, Apache/Nginx 경로 탐색
if [[ -z "$isLocal" ]]; then
    printf "${WARN}$web_server 를 PATH에서 찾을 수 없습니다.\n"
    printf "설치된 경로를 검색합니다.${Color_Off}\n"

    # case 문을 사용하여 Apache와 Nginx를 분기 처리
    case $web_server in
        *httpd*)
            for bin in $HTTPD_TARGETS; do
                if [[ -x "$bin" ]]; then
                    printf "${SUCCESS}Httpd 서버가 $bin 에서 발견되었습니다.${Color_Off}\n"
                    isLocal="$bin"
                    web_server="$bin"
                    break
                fi
            done
            ;;
        *apache*)
            for bin in $APACHE_TARGETS; do
                if [[ -x "$bin" ]]; then
                    printf "${SUCCESS}Apache 서버가 $bin 에서 발견되었습니다.${Color_Off}\n"
                    isLocal="$bin"
                    web_server="$bin"
                    break
                fi
            done
            ;;
        *nginx*)
            for bin in $NGINX_TARGETS; do
                if [[ -x "$bin" ]]; then
                    printf "${SUCCESS}Nginx 서버가 $bin 에서 발견되었습니다.${Color_Off}\n"
                    isLocal="$bin"
                    web_server="$bin"
                    break
                fi
            done
            ;;
        *)
            printf "${DANGER}지원되지 않는 웹서버입니다: $web_server${Color_Off}\n"
            ;;
    esac

    # Apache와 Nginx 모두 찾지 못한 경우 경고
    if [[ -z "$isLocal" ]]; then
        printf "${DANGER}$web_server 서버를 찾을 수 없습니다.${Color_Off}\n"
    fi
fi

if [[ -z "$isLocal" ]]; then
    # 로컬에 설치되어있지 않은 경우. 도커 컨테이너를 확인한다.
    printf "${WARN}로컬에 설치되어있지 않습니다. 도커를 확인해보겠습니다.${Color_Off}\n"
    web_server_container=$(docker ps | grep -E '443' | awk '{ print $2 }')
    # echo $web_server_container
    if [[ -z "$web_server_container" ]]; then
        printf "${DANGER}도커에서 발견되지 않았습니다. 더이상 찾을 수 없으므로 종료합니다.${Color_Off}\n"
        exit 1
    fi

    docker_machin_arch=$(docker exec -i $web_server_container uname -m)
    # echo $docker_machin_arch
    docker_os_name=$(docker exec -i $web_server_container uname -s)
    # echo $docker_os_name
    docker_os_version=$(docker exec -i $web_server_container uname -r)
    # echo $docker_os_version

    printf "${INFO}도커 머신 정보: ${Color_Off}$docker_machin_arch\n"
    printf "${INFO}도커 OS 정보: ${Color_Off}$docker_os_name $docker_os_version\n"
    printf "${INFO}도커 웹서버 정보: ${Color_Off}$web_server\n"

    # 웹 서버 확인을 위한 case 문
    case "$web_server" in
        # httpd 또는 apache인 경우
        *httpd*|*apache*)
            # 웹 서버 버전 확인
            web_server_version=$($web_server -v | grep version | awk '{ print $3 }')
            printf "${INFO}도커 웹서버 버전: ${Color_Off}$web_server_version\n"
            
            # httpd -S 명령어의 출력을 임시 파일에 저장
            output=$($web_server -S 2>/dev/null)

            # httpd -S의 출력을 파싱하여 도메인이 포함된 블록을 추출
            found=$(echo "$output" | awk -v domain="$search_domain_punycode" '
            {
                # 포트가 있는 줄을 만나면 현재 conf 파일 정보 초기화
                if ($1 == "port") {
                    current_conf="";
                }

                # namevhost가 있는 줄에서 conf 파일의 위치를 저장
                if ($1 == "port") {
                    current_conf = $NF;
                }

                # 도메인이나 alias가 포함된 줄을 찾으면 해당 conf 파일 위치 출력
                if ($0 ~ domain) {
                    if (current_conf != "") {
                        print current_conf;
                    }
                }
            }' | sed 's/[()]//g' | sort -u )  # 괄호 제거

            # 결과가 있는지 확인하고 처리
            if [[ -n "$found" ]]; then
                printf "${INFO}conf 파일 위치:\n${SUCCESS}$found\n${Color_Off}"
                # echo $found

                # 각 라인에서 파일 경로와 라인 번호 추출
                while IFS= read -r line; do
                    # 파일 경로와 라인 번호를 ':' 기준으로 분리
                    file_path=$(echo "$line" | cut -d':' -f1)
                    line_number=$(echo "$line" | cut -d':' -f2)

                    printf "${INFO}conf 내용:\n${SUCCESS}$file_path $line_number line.${Color_Off}\n"

                    # 해당 파일의 라인부터 <VirtualHost> 블록 출력
                    sed -n "${line_number},/<\/VirtualHost>/p" "$file_path"

                done <<< "$found"

            else
                printf "${DANGER}Docker: 해당 도메인의 conf 파일을 찾을 수 없습니다.${Color_Off}\n"
            fi
            ;;
            
        # nginx인 경우
        *nginx*)
            printf "${WARN}Nginx 서버에 대한 도메인 확인 기능을 구현 중입니다.${Color_Off}\n"
            web_server_version=$(docker exec -i "$web_server_container" $web_server -v 2>&1 | awk '{ print $3 }')
            printf "${INFO}도커 웹서버 버전: ${Color_Off} $web_server_version\n"

            nginx_conf=$(docker exec -i "$web_server_container" $web_server -t 2>&1 | grep -n file | head -n 1 | awk '{ print $5 }')
            printf "${INFO}도커 웹서버 conf 파일 위치: ${SUCCESS}$nginx_conf${Color_Off}\n"
            nginx_path=$(docker exec -i "$web_server_container" $web_server -T 2>&1 | grep -nE 'ssl_certificate|ssl_certificate_key' | awk '{print $3}' | sort -u | cut -d';' -f1)
            printf "${INFO}도커 conf 내용: \n${SUCCESS}$nginx_path${Color_Off}\n"

            exit 1
            ;;
            
        # 지원하지 않는 웹 서버인 경우
        *)
            printf "${DANGER}지원하지 않는 웹서버입니다.${Color_Off}\n"
            exit 1
            ;;
    esac

else
    # 로컬에 설치되어있는 경우
    # 운영 체제 정보 확인
    machin_arch=$(uname -m)
    os_name=$(uname -s)
    os_version=$(uname -r)

    printf "${INFO}머신 정보: ${Color_Off}$machin_arch\n"
    printf "${INFO}OS 정보: ${Color_Off}$os_name $os_version\n"
    printf "${INFO}웹서버 정보: ${Color_Off}$web_server\n"

    # 웹 서버 확인을 위한 case 문
    case "$web_server" in
        # httpd 또는 apache인 경우
        *httpd*)
            # 웹 서버 버전 확인
            web_server_version=$($web_server -v | grep version | awk '{ print $3 }')
            printf "${INFO}웹서버 버전: ${Color_Off}$web_server_version\n"
            
            # httpd -S 명령어의 출력을 임시 파일에 저장
            output=$($web_server -S 2>/dev/null)

            # httpd -S의 출력을 파싱하여 도메인이 포함된 블록을 추출
            found=$(echo "$output" | awk -v domain="$search_domain_punycode" '
            {
                # 포트가 있는 줄을 만나면 현재 conf 파일 정보 초기화
                if ($1 == "port") {
                    current_conf="";
                }

                # namevhost가 있는 줄에서 conf 파일의 위치를 저장
                if ($1 == "port") {
                    current_conf = $NF;
                }

                # 도메인이나 alias가 포함된 줄을 찾으면 해당 conf 파일 위치 출력
                if ($0 ~ domain) {
                    if (current_conf != "") {
                        print current_conf;
                    }
                }
            }' | sed 's/[()]//g' | sort -u )  # 괄호 제거

            # 결과가 있는지 확인하고 처리
            if [[ -n "$found" ]]; then
                printf "${INFO}conf 파일 위치:\n${SUCCESS}$found\n${Color_Off}"
                # echo $found

                # 각 라인에서 파일 경로와 라인 번호 추출
                while IFS= read -r line; do
                    # 파일 경로와 라인 번호를 ':' 기준으로 분리
                    file_path=$(echo "$line" | cut -d':' -f1)
                    line_number=$(echo "$line" | cut -d':' -f2)

                    printf "${INFO}conf 내용:\n${SUCCESS}$file_path $line_number line.${Color_Off}\n"

                    # 해당 파일의 라인부터 <VirtualHost> 블록 출력
                    sed -n "${line_number},/<\/VirtualHost>/p" "$file_path"

                done <<< "$found"

            else
                printf "${DANGER}HTTPD 해당 도메인의 conf 파일을 찾을 수 없습니다.${Color_Off}\n"
            fi
            ;;
        *apache*)
            # 웹 서버 버전 확인
            web_server='apachectl'
            web_server_version=$($web_server -v | grep version | awk '{ print $3 }')
            printf "${INFO}웹서버 버전: ${Color_Off}$web_server_version\n"
            
            # httpd -S 명령어의 출력을 임시 파일에 저장
            output=$($web_server -S 2>/dev/null)

            # httpd -S의 출력을 파싱하여 도메인이 포함된 블록을 추출
            found=$(echo "$output" | awk -v domain="$search_domain_punycode" '
            {
                # 포트가 있는 줄을 만나면 현재 conf 파일 정보 초기화
                if ($1 == "port") {
                    current_conf="";
                }

                # namevhost가 있는 줄에서 conf 파일의 위치를 저장
                if ($1 == "port") {
                    current_conf = $NF;
                }

                # 도메인이나 alias가 포함된 줄을 찾으면 해당 conf 파일 위치 출력
                if ($0 ~ domain) {
                    if (current_conf != "") {
                        print current_conf;
                    }
                }
            }' | sed 's/[()]//g' | sort -u )  # 괄호 제거

            # 결과가 있는지 확인하고 처리
            if [[ -n "$found" ]]; then
                printf "${INFO}conf 파일 위치:\n${SUCCESS}$found\n${Color_Off}"
                # echo $found

                # 각 라인에서 파일 경로와 라인 번호 추출
                while IFS= read -r line; do
                    # 파일 경로와 라인 번호를 ':' 기준으로 분리
                    file_path=$(echo "$line" | cut -d':' -f1)
                    line_number=$(echo "$line" | cut -d':' -f2)

                    printf "${INFO}conf 내용:\n${SUCCESS}$file_path $line_number line.${Color_Off}\n"

                    # 해당 파일의 라인부터 <VirtualHost> 블록 출력
                    sed -n "${line_number},/<\/VirtualHost>/p" "$file_path"

                done <<< "$found"

            else
                printf "${DANGER}APACHE 해당 도메인의 conf 파일을 찾을 수 없습니다.${Color_Off}\n"
            fi
            ;;
            
        # nginx인 경우
        *nginx*)
            # sshpass -p 'utf-8211of987ram' ssh -o HostKeyAlgorithms=+ssh-rsa root@58.229.176.44 -p38371 'bash -s' < search_domain.sh 베이비.com
            printf "${WARN}Nginx 서버에 대한 도메인 확인 기능을 구현 중입니다.${Color_Off}\n"
            web_server_version=$($web_server -v 2>&1 | grep version | awk '{ print $3 }')
            printf "${INFO}웹서버 버전: ${Color_Off}$web_server_version\n"
            nginx_conf=$($web_server -T 2>&1 | grep "$search_domain_punycode" -B 3 | grep 'configuration file' | awk '{print $4}' | cut -d':' -f1)
            printf "${INFO}$search_domain_punycode conf 파일 위치: ${SUCCESS}$nginx_conf${Color_Off}\n"
            nginx_path=$(cat $nginx_conf | grep -nE '^\s*ssl_certificate|^\*ssl_certificate_key' | awk '{print $3}' | cut -d';' -f1)
            # nginx_path=$($web_server -T 2>&1 | grep -nE "ssl_certificate|ssl_certificate_key" | awk '{print $3}' | sort -u | cut -d';' -f1)
            printf "${INFO}conf 내용: \n${SUCCESS}$nginx_path${Color_Off}\n"

            exit 1
            ;;
            
        # 지원하지 않는 웹 서버인 경우
        *)
            printf "${DANGER}지원하지 않는 웹서버입니다.${Color_Off}\n"
            exit 1
            ;;
    esac
fi

