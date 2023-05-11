--PostgreSQL
--Crear dos tablas la de cuentas con id, saldo, la otra de movimientos con id, tipo de movimiento y monto
CREATE TABLE cuentas(
    id SERIAL PRIMARY KEY,
    saldo NUMERIC CHECK(saldo > 0)
);
CREATE TABLE movimientos(
    id SERIAL PRIMARY KEY,
    tipo CHAR(1) CHECK(tipo IN('D', 'R')),
    monto NUMERIC,
    cuenta_id INTEGER,
    FOREIGN KEY (cuenta_id) REFERENCES cuentas(id)
);

INSERT INTO cuentas(saldo) VALUES(1000);
INSERT INTO cuentas(saldo) VALUES(2000);



--Realizar un pa que: inserte en la tabla de movimientos y actualice el saldo en una transacción

CREATE OR REPLACE PROCEDURE insertar_movimiento(
    tipo CHAR(1),
    monto NUMERIC,
    cuenta_id INTEGER
)
AS $$
BEGIN
    IF monto <= 0 THEN
        RAISE EXCEPTION 'El monto debe ser positivo';
    END IF;

    INSERT INTO movimientos(tipo, monto, cuenta_id) VALUES(tipo, monto, cuenta_id);

    IF tipo = 'D' THEN
        UPDATE cuentas SET saldo = saldo + monto WHERE id = cuenta_id;
    ELSE
        /* IF (SELECT saldo FROM cuentas WHERE id=cuenta_id) < monto THEN
            RAISE EXCEPTION 'Saldo insuficiente';
        END IF; */
        UPDATE cuentas SET saldo = saldo - monto WHERE id = cuenta_id;
    END IF;

    EXCEPTION 
        WHEN OTHERS THEN
        RAISE NOTICE 'Error: %', SQLERRM;
        ROLLBACK;
		COMMIT;
END $$ LANGUAGE 'plpgsql';

call insertar_movimiento('D',-400,1);
call insertar_movimiento('R',4000,2);

CALL insertar_movimiento('D',20,1);
CALL insertar_movimiento('R',20,1);



--Realizar un trigger que cuando inserte en la tabla de movimientos, actualice el saldo en de la tabla cuentas
CREATE OR REPLACE FUNCTION actualizar_saldo()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.tipo = 'D' THEN
        UPDATE cuentas SET saldo = saldo + NEW.monto WHERE id = NEW.cuenta_id;
    ELSE
        UPDATE cuentas SET saldo = saldo - NEW.monto WHERE id = NEW.cuenta_id;
    END IF;

    RETURN NEW;
    EXCEPTION 
        WHEN OTHERS THEN
        RETURN NULL;
END $$ LANGUAGE 'plpgsql';

CREATE TRIGGER actualizar_saldo 
BEFORE INSERT ON movimientos 
FOR EACH ROW EXECUTE PROCEDURE actualizar_saldo();


--Realizar un trigger que cuando se actualice el saldo de la tabla cuentas, inserte un movimiento en la tabla movimientos
CREATE OR REPLACE FUNCTION insertar_movimiento_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.saldo = OLD.saldo THEN
        RETURN null;
    END IF;
    IF NEW.saldo > OLD.saldo THEN
        INSERT INTO movimientos(tipo, monto, cuenta_id) VALUES('D', NEW.saldo - OLD.saldo, NEW.id);
    ELSE
        INSERT INTO movimientos(tipo, monto, cuenta_id) VALUES('R', OLD.saldo - NEW.saldo, NEW.id);
    END IF;

    RETURN null;
END $$ LANGUAGE 'plpgsql';

CREATE TRIGGER insertar_movimiento_trigger
AFTER UPDATE ON cuentas
FOR EACH ROW EXECUTE PROCEDURE insertar_movimiento_trigger();

UPDATE cuentas SET saldo = 2000 WHERE id = 1;