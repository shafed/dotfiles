#!/bin/bash

APP_CLASS="$1"
APP_COMMAND="$2"

# Проверяем, запущено ли приложение
if hyprctl clients | grep "class: $APP_CLASS"; then
  # Если запущено - фокусируемся на нем
  hyprctl dispatch focuswindow "class:$APP_CLASS"
else
  # Если не запущено - запускаем
  $APP_COMMAND &
fi
