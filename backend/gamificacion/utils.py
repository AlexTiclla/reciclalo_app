"""Factores de conversión material -> EcoPuntos / impacto ambiental.

Valores placeholder: deben validarse con el equipo de producto antes de
salir a producción. No bloquean la implementación técnica del flujo.
"""

from decimal import Decimal

# puntos por kg, kg de CO2 evitado por kg, litros de agua ahorrados por kg.
FACTORES_POR_MATERIAL = {
    'plastico': {'puntos': Decimal('15'), 'co2_kg': Decimal('1.5'), 'agua_l': Decimal('3')},
    'carton': {'puntos': Decimal('8'), 'co2_kg': Decimal('0.8'), 'agua_l': Decimal('5')},
    'vidrio': {'puntos': Decimal('6'), 'co2_kg': Decimal('0.3'), 'agua_l': Decimal('1')},
    'metal': {'puntos': Decimal('20'), 'co2_kg': Decimal('2.0'), 'agua_l': Decimal('8')},
}

FACTOR_POR_DEFECTO = {'puntos': Decimal('10'), 'co2_kg': Decimal('1.0'), 'agua_l': Decimal('2')}


def calcular_impacto(tipo_material, peso_kg):
    """
    Devuelve `(puntos: int, co2_kg: Decimal, agua_l: Decimal)` para el peso
    entregado de un material dado.
    """
    factor = FACTORES_POR_MATERIAL.get(tipo_material, FACTOR_POR_DEFECTO)
    peso = Decimal(str(peso_kg))

    puntos = int((factor['puntos'] * peso).to_integral_value(rounding='ROUND_HALF_UP'))
    co2_kg = (factor['co2_kg'] * peso).quantize(Decimal('0.01'))
    agua_l = (factor['agua_l'] * peso).quantize(Decimal('0.01'))

    return puntos, co2_kg, agua_l
