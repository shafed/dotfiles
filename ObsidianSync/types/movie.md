---
limit: 100
mapWithTag: true
icon: clapperboard
tagNames:
  - source/movie
filesPaths: 
bookmarksGroups: 
excludes: 
extends: source
savedViews:
  - name: _➡ default
    children: []
    sorters:
      - id: movie____status
        name: status
        direction: asc
        priority: 1
        customOrder:
          - wip
          - todo
          - done
          - drop
    filters:
      - id: movie____file
        name: file
        query: ""
        customFilter: ""
      - id: movie____status
        name: status
        query: ""
        customFilter: ""
      - id: movie____category
        name: category
        query: ""
        customFilter: ""
      - id: movie____creator
        name: creator
        query: ""
        customFilter: ""
      - id: movie____url
        name: url
        query: ""
        customFilter: ""
      - id: movie____tags
        name: tags
        query: ""
        customFilter: ""
      - id: movie____aliases
        name: aliases
        query: ""
        customFilter: ""
    columns:
      - id: movie____file
        name: file
        hidden: false
        position: 0
      - id: movie____status
        name: status
        hidden: false
        position: 1
      - id: movie____category
        name: category
        hidden: false
        position: 2
      - id: movie____creator
        name: creator
        hidden: false
        position: 3
      - id: movie____url
        name: url
        hidden: false
        position: 4
      - id: movie____tags
        name: tags
        hidden: true
        position: 5
      - id: movie____aliases
        name: aliases
        hidden: true
        position: 6
favoriteView: _➡ default
fieldsOrder: []
version: "2.12"
---

```mdm
type: movie
view: _➡ default
```