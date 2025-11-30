---
limit: 100
mapWithTag: true
icon: book-open
tagNames:
  - source/book
filesPaths: 
bookmarksGroups: 
excludes: 
extends: source
savedViews:
  - name: _➡ default
    children: []
    sorters:
      - id: book____status
        name: status
        direction: asc
        priority: 1
        customOrder:
          - wip
          - todo
          - done
          - drop
    filters:
      - id: book____file
        name: file
        query: ""
        customFilter: ""
      - id: book____status
        name: status
        query: ""
        customFilter: ""
      - id: book____category
        name: category
        query: ""
        customFilter: ""
      - id: book____creator
        name: creator
        query: ""
        customFilter: ""
      - id: book____url
        name: url
        query: ""
        customFilter: ""
      - id: book____tags
        name: tags
        query: ""
        customFilter: ""
      - id: book____aliases
        name: aliases
        query: ""
        customFilter: ""
    columns:
      - id: book____file
        name: file
        hidden: false
        position: 0
      - id: book____status
        name: status
        hidden: false
        position: 1
      - id: book____category
        name: category
        hidden: false
        position: 2
      - id: book____creator
        name: creator
        hidden: false
        position: 3
      - id: book____url
        name: url
        hidden: false
        position: 4
      - id: book____tags
        name: tags
        hidden: true
        position: 5
      - id: book____aliases
        name: aliases
        hidden: true
        position: 6
favoriteView: _➡ default
fieldsOrder: []
version: "2.15"
---

```mdm
type: book
view: _➡ default
```