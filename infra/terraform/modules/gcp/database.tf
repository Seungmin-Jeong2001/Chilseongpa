# ==============================================================================
# [modules/gcp/database.tf] 
# ==============================================================================

resource "google_sql_database_instance" "primary_db" {
  name             = "hybrid-primary-db"
  database_version = "MYSQL_8_0" 
  region           = var.gcp_region

  settings {

    # DB 체급 설정: 부하 테스트를 견딜 수 있도록 vCPU 2개, RAM 7.5GB 할당

    tier = "db-custom-2-7680" 

    

    ip_configuration {


      ipv4_enabled = true 

    }

  }
  
  # 테스트 환경이므로 쉽게 지웠다 만들 수 있도록 삭제 보호 기능 끄기
  deletion_protection = false 
}

# DB 접속용 기본 루트 사용자 생성
resource "google_sql_user" "root_user" {
  name     = "root"
  instance = google_sql_database_instance.primary_db.name
  password = var.gcp_db_password # variables.tf에서 주입받은 비밀번호 사용
}

resource "google_sql_database" "app_db" {
  name     = "hybrid_app_db" # 백엔드 설정에 적어넣을 실제 DB 이름
  instance = google_sql_database_instance.primary_db.name
}
