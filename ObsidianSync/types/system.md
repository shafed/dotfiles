---
limit: 100
mapWithTag: true
icon: wrap-text
tagNames:
  - system/hierarchy
  - system/meta
filesPaths: 
bookmarksGroups: 
excludes: 
extends: 
savedViews:
  - name: _➡ default
    children: []
    sorters: []
    filters:
      - id: system____file
        name: file
        query: ""
      - id: system____tags
        name: tags
        query: ""
      - id: system____aliases
        name: aliases
        query: ""
      - id: system____category
        name: category
        query: ""
    columns:
      - id: system____file
        name: file
        hidden: false
        position: 0
      - id: system____tags
        name: tags
        hidden: true
        position: 1
      - id: system____aliases
        name: aliases
        hidden: true
        position: 2
      - id: system____category
        name: category
        hidden: false
        position: 3
  - name: 🧬 hierarchy
    children: []
    sorters: []
    filters:
      - id: system____file
        name: file
        query: ""
      - id: system____tags
        name: tags
        query: system/hierarchy
      - id: system____aliases
        name: aliases
        query: ""
      - id: system____category
        name: category
        query: ""
    columns:
      - id: system____file
        name: file
        hidden: false
        position: 0
      - id: system____tags
        name: tags
        hidden: true
        position: 1
      - id: system____aliases
        name: aliases
        hidden: true
        position: 2
      - id: system____category
        name: category
        hidden: false
        position: 3
  - name: 🔎 meta
    children: []
    sorters: []
    filters:
      - id: system____file
        name: file
        query: ""
      - id: system____tags
        name: tags
        query: system/meta
      - id: system____aliases
        name: aliases
        query: ""
      - id: system____category
        name: category
        query: ""
    columns:
      - id: system____file
        name: file
        hidden: false
        position: 0
      - id: system____tags
        name: tags
        hidden: true
        position: 1
      - id: system____aliases
        name: aliases
        hidden: true
        position: 2
      - id: system____category
        name: category
        hidden: false
        position: 3
favoriteView: 
fieldsOrder:
  - gvU8ab
  - CQ8Hf8
  - uVXhZ4
version: "2.17"
fields:
  - name: category
    type: MultiFile
    options:
      dvQueryString: dv.pages("#system/category")
    path: ""
    id: uVXhZ4
  - name: tags
    type: Multi
    options:
      sourceType: ValuesList
      valuesList:
        "1": system/meta
        "2": system/hierarchy
    path: ""
    id: gvU8ab
  - name: aliases
    type: YAML
    options: {}
    path: ""
    id: CQ8Hf8
---
