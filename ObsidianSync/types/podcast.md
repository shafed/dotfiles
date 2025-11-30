---
limit: 100
mapWithTag: true
icon: podcast
tagNames:
  - source/podcast
filesPaths: 
bookmarksGroups: 
excludes: 
extends: source
savedViews:
  - name: _➡ default
    children: []
    sorters:
      - id: podcast____status
        name: status
        direction: asc
        priority: 1
        customOrder:
          - wip
          - todo
          - done
          - drop
    filters:
      - id: podcast____file
        name: file
        query: ""
      - id: podcast____status
        name: status
        query: ""
      - id: podcast____category
        name: category
        query: ""
      - id: podcast____creator
        name: creator
        query: ""
      - id: podcast____url
        name: url
        query: ""
      - id: podcast____tags
        name: tags
        query: ""
      - id: podcast____aliases
        name: aliases
        query: ""
    columns:
      - id: podcast____file
        name: file
        hidden: false
        position: 0
      - id: podcast____status
        name: status
        hidden: false
        position: 1
      - id: podcast____category
        name: category
        hidden: false
        position: 2
      - id: podcast____creator
        name: creator
        hidden: false
        position: 3
      - id: podcast____url
        name: url
        hidden: false
        position: 4
      - id: podcast____tags
        name: tags
        hidden: true
        position: 5
      - id: podcast____aliases
        name: aliases
        hidden: true
        position: 6
favoriteView: 
fieldsOrder: []
version: "2.6"
---

```mdm
type: podcast
view: _➡ default
```