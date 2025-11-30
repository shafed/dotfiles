---
limit: 100
mapWithTag: true
icon: graduation-cap
tagNames:
  - source/course
filesPaths: 
bookmarksGroups: 
excludes: 
extends: source
savedViews:
  - name: _➡ default
    children: []
    sorters:
      - id: course____status
        name: status
        direction: asc
        priority: 1
        customOrder:
          - wip
          - todo
          - done
          - drop
    filters:
      - id: course____file
        name: file
        query: ""
        customFilter: ""
      - id: course____status
        name: status
        query: ""
        customFilter: ""
      - id: course____category
        name: category
        query: ""
        customFilter: ""
      - id: course____creator
        name: creator
        query: ""
        customFilter: ""
      - id: course____url
        name: url
        query: ""
        customFilter: ""
      - id: course____tags
        name: tags
        query: ""
        customFilter: ""
      - id: course____aliases
        name: aliases
        query: ""
        customFilter: ""
    columns:
      - id: course____file
        name: file
        hidden: false
        position: 0
      - id: course____status
        name: status
        hidden: false
        position: 1
      - id: course____category
        name: category
        hidden: false
        position: 2
      - id: course____creator
        name: creator
        hidden: false
        position: 3
      - id: course____url
        name: url
        hidden: false
        position: 4
      - id: course____tags
        name: tags
        hidden: true
        position: 5
      - id: course____aliases
        name: aliases
        hidden: true
        position: 6
favoriteView: _➡ default
fieldsOrder: []
version: "2.11"
---

```mdm
type: course
view: _➡default
```