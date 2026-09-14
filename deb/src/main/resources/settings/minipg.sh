#!/bin/bash

SERVICE_NAME="minipg"
HOME_DIR="/etc/bfm/minipg"
PATH_TO_JAR="$HOME_DIR/minipg-app.jar"
PATH_TO_APP_PROP="$HOME_DIR/application.properties"
PID_FILE="$HOME_DIR/minipg.pid"
LOG_FILE="$HOME_DIR/minipg.log"

is_running() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            if grep -q "$PATH_TO_JAR" "/proc/$pid/cmdline" 2>/dev/null; then
                return 0
            fi
        fi
        rm -f "$PID_FILE"
    fi
    return 1
}

start() {
    echo "Starting $SERVICE_NAME ..."

    if is_running; then
        echo "$SERVICE_NAME is already running on PID $(cat "$PID_FILE")"
        return 0
    fi

    if [ ! -f "$PATH_TO_JAR" ]; then
        echo "Error: JAR file not found at $PATH_TO_JAR"
        return 1
    fi

    # Spring Boot konfigürasyonunu JVM parametresi olarak (-D) jar'dan önce geçiriyoruz
    # Log çıktısını parametrik olarak tanımlanan LOG_FILE değişkenine yönlendiriyoruz
    nohup java \
        -Dspring.config.location="$PATH_TO_APP_PROP" \
        -jar "$PATH_TO_JAR" \
        >> "$LOG_FILE" 2>&1 &

    local pid=$!
    echo "$pid" > "$PID_FILE"

    sleep 2

    if kill -0 "$pid" 2>/dev/null; then
        echo "$SERVICE_NAME started on PID $pid"
        return 0
    else
        rm -f "$PID_FILE"
        echo "Error: $SERVICE_NAME could not start. Check $LOG_FILE for details."
        return 1
    fi
}

stop() {
    if ! is_running; then
        echo "$SERVICE_NAME is not running"
        rm -f "$PID_FILE" 2>/dev/null
        return 0
    fi

    local pid
    pid=$(cat "$PID_FILE")

    echo "Stopping $SERVICE_NAME (PID=$pid)..."
    kill "$pid" 2>/dev/null

    local count=0
    while kill -0 "$pid" 2>/dev/null; do
        if [ $count -ge 30 ]; then
            echo "Force killing PID $pid..."
            kill -9 "$pid" 2>/dev/null
            break
        fi
        sleep 1
        ((count++))
    done

    rm -f "$PID_FILE"
    echo "$SERVICE_NAME stopped"
    return 0
}

restart() {
    stop
    sleep 2
    start
}

status() {
    if is_running; then
        echo "$SERVICE_NAME is running on PID $(cat "$PID_FILE")"
        return 0
    else
        echo "$SERVICE_NAME is stopped"
        return 3
    fi
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    status)
        status
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac

exit $?