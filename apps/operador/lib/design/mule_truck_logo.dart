import 'package:flutter/material.dart';

/// LOGO_MULEAGENT_V1, imagen PNG aprobada por el usuario.
/// No redibujar ni cambiar colores, placa, proporciones o composición.
class MuleTruckLogo extends StatelessWidget {
  const MuleTruckLogo({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Logo MuleAgent: tractor de patio con placa M amarilla',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: Image.asset(
        'assets/LOGO_MULEAGENT_V1.png',
        package: 'operador',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
      ),
    ),
  );
}
