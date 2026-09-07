.PHONY: setup verify run

setup:
	@mkdir -p artifacts evidence docs db/migrations db/seed src tests
	@test -f .env.example
	@docker compose up -d postgres
	@echo "Esperando a PostgreSQL..."
	@until docker compose exec -T postgres pg_isready -U $${POSTGRES_USER:-cdrl_dev} -d $${POSTGRES_DB:-cdrl} > /dev/null 2>&1; do sleep 1; done
	@bash scripts/migrate.sh
	@bash scripts/seed.sh
	@echo "CDRL M01 preparado correctamente."

verify:
	@bash scripts/verify_base.sh
	@bash scripts/verify_m01.sh

run:
	@docker compose up

migrate:
	@bash scripts/migrate.sh

seed:
	@bash scripts/seed.sh

test:
	@bash scripts/verify_m01.sh

down:
	@docker compose down