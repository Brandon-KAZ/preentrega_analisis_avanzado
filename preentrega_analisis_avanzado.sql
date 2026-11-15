/* =====================================================================
   PRE-ENTREGA: Script de analisis avanzado con Window Functions
   Brandon Zalazar
   Reporte mensual por categoria con: mes, categoria, venta total,
   ranking dentro del mes, acumulado por categoria y comparativa
   contra el promedio historico ('Exitoso' / 'Bajo el promedio').
   ===================================================================== */

/* =====================================================================
   PARTE 1: CREACION DE TABLAS Y DATOS DE PRUEBA
   ===================================================================== */

DROP TABLE IF EXISTS ventas;
DROP TABLE IF EXISTS productos;
DROP TABLE IF EXISTS categorias;

-- Categorias de los productos

CREATE TABLE categorias (
    id_categoria SERIAL PRIMARY KEY,
    nombre       VARCHAR(50) NOT NULL UNIQUE
);

-- Productos, cada uno pertenece a una categoria

CREATE TABLE productos (
    id_producto  SERIAL PRIMARY KEY,
    nombre       VARCHAR(100) NOT NULL,
    precio       NUMERIC(10,2) NOT NULL CHECK (precio > 0),
    id_categoria INT NOT NULL REFERENCES categorias(id_categoria)
);

-- Ventas: cada fila es una venta de un producto en una fecha

CREATE TABLE ventas (
    id_venta    SERIAL PRIMARY KEY,
    id_producto INT NOT NULL REFERENCES productos(id_producto),
    fecha       DATE NOT NULL,
    cantidad    INT NOT NULL CHECK (cantidad > 0)
);

INSERT INTO categorias (nombre) VALUES
    ('Electronica'),
    ('Accesorios'),
    ('Hogar');

INSERT INTO productos (nombre, precio, id_categoria) VALUES
    ('Auriculares Bluetooth', 25000, 1),
    ('Teclado mecanico',      40000, 1),
    ('Mochila urbana',        18000, 2),
    ('Botella termica',        8000, 2),
    ('Lampara de mesa',       12000, 3),
    ('Cafetera',              30000, 3);

INSERT INTO ventas (id_producto, fecha, cantidad) VALUES
    -- Enero 2026
    (1, '2026-01-05', 2),
    (3, '2026-01-10', 3),
    (5, '2026-01-15', 4),
    (6, '2026-01-20', 1),
    -- Febrero 2026
    (1, '2026-02-03', 1),
    (2, '2026-02-12', 2),
    (3, '2026-02-18', 5),
    (4, '2026-02-22', 6),
    (6, '2026-02-25', 2),
    -- Marzo 2026
    (1, '2026-03-04', 4),
    (2, '2026-03-11', 1),
    (3, '2026-03-19', 1),
    (5, '2026-03-23', 2),
    (6, '2026-03-28', 3),
    -- Abril 2026
    (2, '2026-04-06', 3),
    (4, '2026-04-14', 4),
    (3, '2026-04-20', 2),
    (5, '2026-04-24', 6),
    (6, '2026-04-29', 1);

/* =====================================================================
   PARTE 2: CONSULTA DE ANÁLISIS AVANZADO
   ===================================================================== */

/* CTE 1: ventas_mensuales
   Agrupa las ventas por mes y categoria.
   - DATE_TRUNC('month', ...) normaliza cada fecha al primer dia del mes.
   - SUM(...) calcula la venta total de cada categoria en ese mes. */
WITH ventas_mensuales AS (
    SELECT
        DATE_TRUNC('month', v.fecha)::date AS mes,
        c.nombre                           AS categoria,
        SUM(v.cantidad * p.precio)         AS venta_total
    FROM ventas v
    INNER JOIN productos  p ON p.id_producto  = v.id_producto
    INNER JOIN categorias c ON c.id_categoria = p.id_categoria
    GROUP BY
        DATE_TRUNC('month', v.fecha),
        c.nombre
),

/* CTE 2: metricas_ventana
   Aplica Window Functions sobre ventas_mensuales.
   - RANK(): posicion de cada categoria dentro de su mes (1 = la mas vendida).
   - SUM() OVER (... ORDER BY mes): running total de ventas por categoria. */
metricas_ventana AS (
    SELECT
        mes,
        categoria,
        venta_total,
        RANK() OVER (
            PARTITION BY mes
            ORDER BY venta_total DESC
        ) AS ranking_mes,
        SUM(venta_total) OVER (
            PARTITION BY categoria
            ORDER BY mes
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS acumulado_categoria
    FROM ventas_mensuales
)

/* SELECT final
   Compara la venta del mes contra el promedio historico mensual de su
   categoria y devuelve 'Exitoso' o 'Bajo el promedio'. */
   
SELECT
    mes,
    categoria,
    venta_total,
    ranking_mes,
    acumulado_categoria,
    CASE
        WHEN venta_total >= AVG(venta_total) OVER (PARTITION BY categoria)
            THEN 'Exitoso'
        ELSE 'Bajo el promedio'
    END AS comparativa
FROM metricas_ventana
ORDER BY
    mes,
    ranking_mes;