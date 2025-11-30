---
fields:
  - name: status
    type: Select
    options:
      sourceType: ValuesList
      valuesList:
        "1": todo
        "2": wip
        "3": done
        "4": drop
    path: ""
    id: X8DqTr
  - name: category
    type: MultiFile
    options:
      dvQueryString: dv.pages("#system/category")
    path: ""
    id: Z6scff
  - name: creator
    type: MultiFile
    options:
      dvQueryString: dv.pages("#people/creator")
    path: ""
    id: XOQ8mY
  - name: url
    type: Input
    options:
      template: "{{URL}}"
    path: ""
    id: HQgp9o
  - name: tags
    type: Multi
    options:
      sourceType: ValuesList
      valuesList:
        "1": source/article
        "2": source/book
        "3": source/course
        "4": source/movie
        "5": source/podcast
        "6": source/video
    path: ""
    id: o1dhUo
  - name: aliases
    type: YAML
    options: {}
    path: ""
    id: Sz2zbC
version: "2.173"
limit: 100
mapWithTag: false
icon: archive
tagNames: 
filesPaths:
  - sources
bookmarksGroups: 
excludes: 
extends: 
savedViews:
  - name: _➡ default
    children: []
    sorters:
      - id: source____status
        name: status
        direction: asc
        priority: 1
        customOrder:
          - wip
          - todo
          - done
          - drop
    filters:
      - id: source____file
        name: file
        query: ""
        customFilter: ""
      - id: source____tags
        name: tags
        query: ""
        customFilter: ""
      - id: source____aliases
        name: aliases
        query: ""
        customFilter: ""
      - id: source____status
        name: status
        query: ""
        customFilter: ""
      - id: source____category
        name: category
        query: ""
        customFilter: ""
      - id: source____creator
        name: creator
        query: ""
        customFilter: ""
      - id: source____url
        name: url
        query: ""
        customFilter: ""
    columns:
      - id: source____file
        name: file
        hidden: false
        position: 0
      - id: source____tags
        name: tags
        hidden: true
        position: 1
      - id: source____aliases
        name: aliases
        hidden: true
        position: 2
      - id: source____status
        name: status
        hidden: false
        position: 1
      - id: source____category
        name: category
        hidden: false
        position: 2
      - id: source____creator
        name: creator
        hidden: false
        position: 4
      - id: source____url
        name: url
        hidden: false
        position: 5
  - name: ⬛ drop
    children: []
    sorters: []
    filters:
      - id: source____file
        name: file
        query: ""
        customFilter: ""
      - id: source____tags
        name: tags
        query: ""
        customFilter: ""
      - id: source____aliases
        name: aliases
        query: ""
        customFilter: ""
      - id: source____status
        name: status
        query: drop
        customFilter: ""
      - id: source____category
        name: category
        query: ""
        customFilter: ""
      - id: source____creator
        name: creator
        query: ""
        customFilter: ""
      - id: source____url
        name: url
        query: ""
        customFilter: ""
    columns:
      - id: source____file
        name: file
        hidden: false
        position: 0
      - id: source____tags
        name: tags
        hidden: true
        position: 1
      - id: source____aliases
        name: aliases
        hidden: true
        position: 2
      - id: source____status
        name: status
        hidden: true
        position: 1
      - id: source____category
        name: category
        hidden: false
        position: 2
      - id: source____creator
        name: creator
        hidden: false
        position: 4
      - id: source____url
        name: url
        hidden: false
        position: 5
  - name: 🟥 todo
    children: []
    sorters: []
    filters:
      - id: source____file
        name: file
        query: ""
        customFilter: ""
      - id: source____tags
        name: tags
        query: ""
        customFilter: ""
      - id: source____aliases
        name: aliases
        query: ""
        customFilter: ""
      - id: source____status
        name: status
        query: todo
        customFilter: ""
      - id: source____category
        name: category
        query: ""
        customFilter: ""
      - id: source____creator
        name: creator
        query: ""
        customFilter: ""
      - id: source____url
        name: url
        query: ""
        customFilter: ""
    columns:
      - id: source____file
        name: file
        hidden: false
        position: 0
      - id: source____tags
        name: tags
        hidden: true
        position: 1
      - id: source____aliases
        name: aliases
        hidden: true
        position: 2
      - id: source____status
        name: status
        hidden: true
        position: 1
      - id: source____category
        name: category
        hidden: false
        position: 2
      - id: source____creator
        name: creator
        hidden: false
        position: 4
      - id: source____url
        name: url
        hidden: false
        position: 5
  - name: 🟦 wip
    children: []
    sorters: []
    filters:
      - id: source____file
        name: file
        query: ""
        customFilter: ""
      - id: source____tags
        name: tags
        query: ""
        customFilter: ""
      - id: source____aliases
        name: aliases
        query: ""
        customFilter: ""
      - id: source____status
        name: status
        query: wip
        customFilter: ""
      - id: source____category
        name: category
        query: ""
        customFilter: ""
      - id: source____creator
        name: creator
        query: ""
        customFilter: ""
      - id: source____url
        name: url
        query: ""
        customFilter: ""
    columns:
      - id: source____file
        name: file
        hidden: false
        position: 0
      - id: source____tags
        name: tags
        hidden: true
        position: 1
      - id: source____aliases
        name: aliases
        hidden: true
        position: 2
      - id: source____status
        name: status
        hidden: true
        position: 1
      - id: source____category
        name: category
        hidden: false
        position: 2
      - id: source____creator
        name: creator
        hidden: false
        position: 4
      - id: source____url
        name: url
        hidden: false
        position: 5
  - name: 🟩 done
    children: []
    sorters: []
    filters:
      - id: source____file
        name: file
        query: ""
        customFilter: ""
      - id: source____tags
        name: tags
        query: ""
        customFilter: ""
      - id: source____aliases
        name: aliases
        query: ""
        customFilter: ""
      - id: source____status
        name: status
        query: done
        customFilter: ""
      - id: source____category
        name: category
        query: ""
        customFilter: ""
      - id: source____creator
        name: creator
        query: ""
        customFilter: ""
      - id: source____url
        name: url
        query: ""
        customFilter: ""
    columns:
      - id: source____file
        name: file
        hidden: false
        position: 0
      - id: source____tags
        name: tags
        hidden: true
        position: 1
      - id: source____aliases
        name: aliases
        hidden: true
        position: 2
      - id: source____status
        name: status
        hidden: true
        position: 1
      - id: source____category
        name: category
        hidden: false
        position: 2
      - id: source____creator
        name: creator
        hidden: false
        position: 4
      - id: source____url
        name: url
        hidden: false
        position: 5
favoriteView: _➡ default
fieldsOrder:
  - o1dhUo
  - Sz2zbC
  - X8DqTr
  - Z6scff
  - XOQ8mY
  - HQgp9o
---

```mdm
type: source
view: default
```