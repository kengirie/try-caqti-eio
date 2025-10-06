open Eio.Std

let default_uri = "sqlite3:./data.sqlite3"

let resolve_uri = function
  | Some uri -> Uri.of_string uri
  | None -> Uri.of_string default_uri

let with_connection ?uri ~sw ~stdenv f =
  let uri = resolve_uri uri in
  let conn =
    Caqti_eio_unix.connect ~sw ~stdenv uri |> Caqti_eio.or_fail
  in
  Fun.protect ~finally:(fun () ->
      let (module Db : Caqti_eio.CONNECTION) = conn in
      Db.disconnect ())
    (fun () -> f conn)

module Schema = struct
  open Caqti_request.Infix

  let create_organizations =
    (Caqti_type.unit ->. Caqti_type.unit)
      {|
        CREATE TABLE IF NOT EXISTS organizations (
          organization_code TEXT PRIMARY KEY,
          start_date TEXT NOT NULL,
          end_date TEXT,
          name TEXT NOT NULL,
          type_code TEXT,
          parent_organization_code TEXT REFERENCES organizations(organization_code),
          parent_start_date TEXT
        )
      |}

  let create_positions =
    (Caqti_type.unit ->. Caqti_type.unit)
      {|
        CREATE TABLE IF NOT EXISTS positions (
          position_code TEXT PRIMARY KEY,
          position_name TEXT NOT NULL,
          allocation_category TEXT
        )
      |}

  let create_employees =
    (Caqti_type.unit ->. Caqti_type.unit)
      {|
        CREATE TABLE IF NOT EXISTS employees (
          employee_code TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          birth_date TEXT NOT NULL,
          email TEXT,
          address TEXT
        )
      |}

  let create_affiliations =
    (Caqti_type.unit ->. Caqti_type.unit)
      {|
        CREATE TABLE IF NOT EXISTS affiliations (
          affiliation_id INTEGER PRIMARY KEY AUTOINCREMENT,
          employee_code TEXT NOT NULL REFERENCES employees(employee_code),
          organization_code TEXT NOT NULL REFERENCES organizations(organization_code),
          organization_start_date TEXT,
          start_date TEXT NOT NULL,
          end_date TEXT,
          position_code TEXT REFERENCES positions(position_code),
          position_start_date TEXT,
          position_end_date TEXT,
          UNIQUE (employee_code, start_date)
        )
      |}

  let create_kpis =
    (Caqti_type.unit ->. Caqti_type.unit)
      {|
        CREATE TABLE IF NOT EXISTS kpis (
          kpi_code TEXT NOT NULL,
          fiscal_year INTEGER NOT NULL,
          name TEXT NOT NULL,
          target_value REAL,
          PRIMARY KEY (kpi_code, fiscal_year)
        )
      |}

  let create_monthly_targets =
    (Caqti_type.unit ->. Caqti_type.unit)
      {|
        CREATE TABLE IF NOT EXISTS monthly_individual_targets (
          employee_code TEXT NOT NULL REFERENCES employees(employee_code),
          kpi_code TEXT NOT NULL,
          fiscal_year INTEGER NOT NULL,
          month TEXT NOT NULL,
          target_value REAL,
          PRIMARY KEY (employee_code, kpi_code, fiscal_year, month),
          FOREIGN KEY (kpi_code, fiscal_year) REFERENCES kpis(kpi_code, fiscal_year)
        )
      |}

  let create_monthly_performance =
    (Caqti_type.unit ->. Caqti_type.unit)
      {|
        CREATE TABLE IF NOT EXISTS monthly_individual_performance (
          employee_code TEXT NOT NULL REFERENCES employees(employee_code),
          kpi_code TEXT NOT NULL,
          fiscal_year INTEGER NOT NULL,
          month TEXT NOT NULL,
          actual_value REAL,
          PRIMARY KEY (employee_code, kpi_code, fiscal_year, month),
          FOREIGN KEY (kpi_code, fiscal_year) REFERENCES kpis(kpi_code, fiscal_year)
        )
      |}

  let all =
    [ create_organizations;
      create_positions;
      create_employees;
      create_affiliations;
      create_kpis;
      create_monthly_targets;
      create_monthly_performance ]
end

module Seed = struct
  open Caqti_request.Infix

  let insert_org_hq =
    (Caqti_type.unit ->. Caqti_type.unit)
      "INSERT OR IGNORE INTO organizations
         (organization_code, start_date, end_date, name, type_code, parent_organization_code, parent_start_date)
       VALUES ('HQ', '2010-04-01', NULL, '本社', 'HEAD', NULL, NULL)"

  let insert_org_sales =
    (Caqti_type.unit ->. Caqti_type.unit)
      "INSERT OR IGNORE INTO organizations
         (organization_code, start_date, end_date, name, type_code, parent_organization_code, parent_start_date)
       VALUES ('SALES', '2015-04-01', NULL, '営業本部', 'DIV', 'HQ', '2015-04-01')"

  let insert_position_mgr =
    (Caqti_type.unit ->. Caqti_type.unit)
      "INSERT OR IGNORE INTO positions (position_code, position_name, allocation_category)
       VALUES ('MGR', 'マネージャ', 'manager')"

  let insert_position_rep =
    (Caqti_type.unit ->. Caqti_type.unit)
      "INSERT OR IGNORE INTO positions (position_code, position_name, allocation_category)
       VALUES ('REP', '営業担当', 'staff')"

  let insert_employee =
    (Caqti_type.unit ->. Caqti_type.unit)
      "INSERT OR IGNORE INTO employees (employee_code, name, birth_date, email, address)
       VALUES ('E0001', '田中 太郎', '1990-05-12', 'tanaka@example.com', '東京都千代田区1-1-1')"

  let insert_affiliation =
    (Caqti_type.unit ->. Caqti_type.unit)
      "INSERT OR IGNORE INTO affiliations
         (employee_code, organization_code, organization_start_date, start_date, end_date, position_code, position_start_date, position_end_date)
       VALUES ('E0001', 'SALES', '2015-04-01', '2024-04-01', NULL, 'REP', '2024-04-01', NULL)"

  let insert_kpi =
    (Caqti_type.unit ->. Caqti_type.unit)
      "INSERT OR IGNORE INTO kpis (kpi_code, fiscal_year, name, target_value)
       VALUES ('KPI-001', 2025, '新規受注件数', 120.0)"

  let insert_target_apr =
    (Caqti_type.unit ->. Caqti_type.unit)
      "INSERT OR REPLACE INTO monthly_individual_targets
         (employee_code, kpi_code, fiscal_year, month, target_value)
       VALUES ('E0001', 'KPI-001', 2025, '2025-04', 10.0)"

  let insert_target_may =
    (Caqti_type.unit ->. Caqti_type.unit)
      "INSERT OR REPLACE INTO monthly_individual_targets
         (employee_code, kpi_code, fiscal_year, month, target_value)
       VALUES ('E0001', 'KPI-001', 2025, '2025-05', 12.0)"

  let insert_performance_apr =
    (Caqti_type.unit ->. Caqti_type.unit)
      "INSERT OR REPLACE INTO monthly_individual_performance
         (employee_code, kpi_code, fiscal_year, month, actual_value)
       VALUES ('E0001', 'KPI-001', 2025, '2025-04', 9.0)"

  let insert_performance_may =
    (Caqti_type.unit ->. Caqti_type.unit)
      "INSERT OR REPLACE INTO monthly_individual_performance
         (employee_code, kpi_code, fiscal_year, month, actual_value)
       VALUES ('E0001', 'KPI-001', 2025, '2025-05', 13.5)"

  let statements =
    [ insert_org_hq;
      insert_org_sales;
      insert_position_mgr;
      insert_position_rep;
      insert_employee;
      insert_affiliation;
      insert_kpi;
      insert_target_apr;
      insert_target_may;
      insert_performance_apr;
      insert_performance_may ]
end

module Reports = struct
  open Caqti_request.Infix

  let employee_monthly_summary =
    let row_type =
      let open Caqti_type in
      t2
        (t4 string string (option string) string)
        (t2 (option float) (option float))
    in
    let sql = String.trim {|
        SELECT
          e.employee_code,
          e.name,
          o.name AS organization_name,
          t.month,
          t.target_value,
          p.actual_value
        FROM monthly_individual_targets AS t
        JOIN employees AS e
          ON e.employee_code = t.employee_code
        LEFT JOIN monthly_individual_performance AS p
          ON p.employee_code = t.employee_code
         AND p.kpi_code = t.kpi_code
         AND p.fiscal_year = t.fiscal_year
         AND p.month = t.month
        LEFT JOIN affiliations AS a
          ON a.employee_code = e.employee_code
        LEFT JOIN organizations AS o
          ON o.organization_code = a.organization_code
        WHERE t.fiscal_year = 2025
        ORDER BY e.employee_code, t.month;
      |} in
    (Caqti_type.unit ->* row_type) sql
end

let ensure_schema ?uri ~sw ~stdenv () =
  with_connection ?uri ~sw ~stdenv @@ fun (module Db : Caqti_eio.CONNECTION) ->
  List.iter
    (fun request -> Db.exec request () |> Caqti_eio.or_fail)
    Schema.all

let demo_run ?uri ~sw ~stdenv () =
  with_connection ?uri ~sw ~stdenv @@ fun (module Db : Caqti_eio.CONNECTION) ->
  let exec_unit req = Db.exec req () |> Caqti_eio.or_fail in
  List.iter exec_unit Seed.statements;
  let format_float_opt = function
    | Some v -> Printf.sprintf "%.1f" v
    | None -> "-"
  in
  Db.collect_list Reports.employee_monthly_summary ()
  |> Caqti_eio.or_fail
  |> List.iter (fun ((code, name, org_name_opt, month), (target_opt, actual_opt)) ->
         let org_name = Option.value org_name_opt ~default:"(未所属)" in
         traceln "employee=%s name=%s org=%s month=%s target=%s actual=%s"
           code name org_name month
           (format_float_opt target_opt)
           (format_float_opt actual_opt))
