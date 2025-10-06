# 人事 / KPI 管理システム ER 図

以下はスクリーンショットで提供された ER 図をベースにしたテキスト表現です。Mermaid をサポートするビューアで表示すると図としてレンダリングできます。

```mermaid
erDiagram
    ORGANIZATIONS ||--o{ AFFILIATIONS : "a 所属"
    POSITIONS ||--o{ AFFILIATIONS : "役職配属"
    EMPLOYEES ||--o{ AFFILIATIONS : "b 従業員→所属"
    KPIS ||--o{ MONTHLY_INDIVIDUAL_TARGETS : "KPI目標"
    KPIS ||--o{ MONTHLY_INDIVIDUAL_PERFORMANCE : "KPI実績"
    EMPLOYEES ||--o{ MONTHLY_INDIVIDUAL_TARGETS : "b 従業員→月別目標"
    EMPLOYEES ||--o{ MONTHLY_INDIVIDUAL_PERFORMANCE : "b 従業員→月別実績"

    ORGANIZATIONS {
        TEXT organization_code PK
        TEXT start_date
        TEXT end_date
        TEXT name
        TEXT type_code
        TEXT parent_organization_code FK
        TEXT parent_start_date
    }

    POSITIONS {
        TEXT position_code PK
        TEXT position_name
        TEXT allocation_category
    }

    EMPLOYEES {
        TEXT employee_code PK
        TEXT name
        TEXT birth_date
        TEXT email
        TEXT address
    }

    AFFILIATIONS {
        INTEGER affiliation_id PK
        TEXT employee_code FK
        TEXT organization_code FK
        TEXT organization_start_date
        TEXT start_date UK
        TEXT end_date
        TEXT position_code FK
        TEXT position_start_date
        TEXT position_end_date
    }

    KPIS {
        TEXT kpi_code PK
        INTEGER fiscal_year PK
        TEXT name
        REAL target_value
    }

    MONTHLY_INDIVIDUAL_TARGETS {
        TEXT employee_code PK FK
        TEXT kpi_code PK FK
        INTEGER fiscal_year PK
        TEXT month PK
        REAL target_value
    }

    MONTHLY_INDIVIDUAL_PERFORMANCE {
        TEXT employee_code PK FK
        TEXT kpi_code PK FK
        INTEGER fiscal_year PK
        TEXT month PK
        REAL actual_value
    }
```

- リレーション **a**: 1 つの組織が複数の所属 (`AFFILIATIONS`) を持つ関係です。
- リレーション **b**: `EMPLOYEES` の従業員コードをキーとして、所属および月次目標 / 実績がぶら下がる関係です。
- KPI 系テーブルは主キー `(kpi_code, fiscal_year)` を共有し、同じ複合キーを外部キーとして参照します。
