---
id: Day 1
aliases:
  - день 1
tags: []
---

```meta-bind-button
label: Copy Data
icon: ""
style: plain
class: ""
cssStyle: ""
backgroundImage: ""
tooltip: ""
id: ""
hidden: false
actions:
  - type: inlineJS
    code: |-
      try {
          // Получаем активный файл и его содержимое
          const activeFile = app.workspace.getActiveFile();
          const content = await app.vault.read(activeFile);
          
          console.log('Содержимое получено');
          
          // Находим все таблицы в файле
          const tableRegex = /(\|[^\n]+\|\n)+/g;
          const tables = content.match(tableRegex);
          
          if (!tables || tables.length === 0) {
              new Notice('Таблицы не найдены!');
              return;
          }
          
          console.log('Найдено таблиц:', tables.length);
          
          // Берем последнюю таблицу
          const lastTable = tables[tables.length - 1];
          const lines = lastTable.trim().split('\n');
          
          console.log('Строк в таблице:', lines.length);
          
          // Пропускаем заголовок и разделитель (первые 2 строки)
          const dataLines = lines.slice(2);
          
          const result = [];
          
          dataLines.forEach(line => {
              const cells = line.split('|').map(cell => cell.trim());
              
              if (cells.length >= 5) {
                  const reps = cells[3];
                  const weight = cells[4];
                  
                  let processedReps = reps;
                  
                  // Исправленное регулярное выражение
                  const match = reps.match(/^\d+X([\d-,]+)$/);
                  if (match && match[1].includes('-')) {
                      processedReps = match[1];
                  }
                  
                  result.push(processedReps);
                  result.push(weight);
                  result.push('kg');
              }
          });
          
          const outputString = result.join('\t');
          console.log('Результат:', outputString);
          
          if (outputString) {
              // Копирование в буфер обмена
              await navigator.clipboard.writeText(outputString);
              new Notice('Скопировано в буфер обмена!');
          } else {
              new Notice('Нет данных для копирования!');
          }
          
      } catch (error) {
          console.error('Ошибка:', error);
          new Notice('Ошибка: ' + error.message);
      }
    args: {}

```

| #   | Exercise        | Reps       | Weight |
| --- | --------------- | ---------- | ------ |
| 1   | HB Squat        | 3X9        | 65     |
| 2   | RDL             | 3X9        | 65     |
| 3A  | Cable Fly       | 3X8        | 30     |
| 3B  | Neutral-Ups     | 3X10-9-7   | 82,7+5 |
| 4A  | Cable Curl      | 3X13-12-11 | 13     |
| 4B  | U OHE           | 3X12       | 10     |
| 5A  | Len Seated Calf | 3X20       | 50     |
| 5B  | Cable Crunch    | 3X12-11-11 | 83     |
| 5C  | Neck Curl       | 3X20       | 8,75   |

- fly: +4 rep, not +6
- calf: 90 degree in hip
