---
limit: 100
mapWithTag: true
icon: sticky-note
tagNames:
  - source/article
filesPaths: 
bookmarksGroups: 
excludes: 
extends: source
savedViews:
  - name: _➡ default
    children: []
    sorters:
      - id: article____status
        name: status
        direction: asc
        priority: 1
        customOrder:
          - wip
          - todo
          - done
          - drop
    filters:
      - id: article____file
        name: file
        query: ""
        customFilter: ""
      - id: article____status
        name: status
        query: ""
        customFilter: ""
      - id: article____category
        name: category
        query: ""
        customFilter: ""
      - id: article____creator
        name: creator
        query: ""
        customFilter: ""
      - id: article____url
        name: url
        query: ""
        customFilter: ""
      - id: article____tags
        name: tags
        query: ""
        customFilter: ""
      - id: article____aliases
        name: aliases
        query: ""
        customFilter: ""
    columns:
      - id: article____file
        name: file
        hidden: false
        position: 0
      - id: article____status
        name: status
        hidden: false
        position: 1
      - id: article____category
        name: category
        hidden: false
        position: 2
      - id: article____creator
        name: creator
        hidden: false
        position: 3
      - id: article____url
        name: url
        hidden: false
        position: 4
      - id: article____tags
        name: tags
        hidden: true
        position: 5
      - id: article____aliases
        name: aliases
        hidden: true
        position: 6
favoriteView: 
fieldsOrder: []
version: "2.9"
---

```mdm
type: article
view: _➡ default
```