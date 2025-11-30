---
id: Day 3
aliases:
  - день 3
tags:
  - note/basic
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

| #   | Exercise       | Reps       | Weight              |
| --- | -------------- | ---------- | ------------------- |
| 1A  | SM Incline BP  | 4X8        | 54,5-54,5-54,5-59,5 |
| 2B  | Ch-S Row       | 4X12       | 35                  |
| 2A  | Leg Press      | 3X10       | 120                 |
| 2B  | BB Curl        | 3X8        | 33,5                |
| 3A  | Hyperextension | 3X8        | 43                  |
| 3B  | UL Pushdown    | 3X10       | 25                  |
| 4   | AD Press       | 3X14-14-10 | 35                  |
| 5A  | Rev M Fly      | 3X18-18-15 | 50                  |
| 5B  | BB Wrist Curl  | 3X15       | 51                  |



> [!Note]- Comments
> 1. Chest: in 3-rd set forget that I add weight.
> 2. Hamstrings: do hip hinge not back hinge.
> 3. Rear Delts: need slower negative, do under control.
> 4. AD Press: control disbalance between arm.
