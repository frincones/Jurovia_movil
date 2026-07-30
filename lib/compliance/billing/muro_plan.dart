import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/typography.dart';
import '../../shared/models/me.dart';
import 'billing_policy.dart';

/// Muro de plan: explica que la facturación **no se gestiona en la app**.
///
/// No es un *paywall*: no vende, no enlaza y no invita a comprar. Es lo
/// contrario — la respuesta honesta a «¿por qué no puedo hacer esto aquí?».
///
/// Antes de esto la app simplemente callaba: la píldora de cuota no reaccionaba
/// al toque, el aviso de bloqueo no explicaba nada y Perfil no tenía ninguna
/// fila de facturación. Un abogado lo leía como una pantalla a medias, y un
/// revisor de Apple, como algo que se le está ocultando. Decirlo claro es mejor
/// producto **y** más seguro en revisión.
///
/// Ver [`PROPUESTA_MURO_PLAN.md`](../../../PROPUESTA_MURO_PLAN.md) y
/// `AuditCheck.md` §3.3.
abstract final class MuroPlan {
  /// Muestra el muro. `detalle` es el mensaje concreto del servidor (p. ej. el
  /// del evento `blocked`), que va **antes** de la explicación: lo urgente
  /// primero, el modelo de negocio después.
  static Future<void> mostrar(
    BuildContext context, {
    required MotivoMuro motivo,
    Me? me,
    String? detalle,
  }) {
    final FuenteSuscripcion fuente = BillingPolicy.fuente(me);
    return showDialog<void>(
      context: context,
      builder: (BuildContext c) => _Dialogo(
        titulo: TextosMuro.titulo(motivo),
        detalle: detalle,
        explicacion: TextosMuro.explicacion(fuente),
      ),
    );
  }

  /// ¿El plan habilita esta capacidad?
  ///
  /// **Fail-open, igual que el backend.** `plans.has_entitlement()` trata una
  /// clave ausente como permitida, así que el cliente tiene que hacer lo mismo:
  /// exigir `== true` bloquearía funciones que el servidor sí permite y el
  /// abogado vería desaparecer algo que le corresponde. Solo un `false`
  /// explícito niega.
  static bool habilitado(Me? me, String entitlement) {
    final Object? v = me?.entitlements[entitlement];
    return v != false;
  }

  /// Guarda para módulos con *entitlement*: `false` si no tiene acceso, y de
  /// paso se lo explica.
  ///
  /// Que un módulo desaparezca sin más deja al abogado creyendo que la función
  /// no existe. Decirle que no está en su plan es información; esconderla, no.
  ///
  /// Hoy **ningún módulo llama a esto**: los planes actuales no niegan ninguna
  /// capacidad de forma explícita, y añadir una puerta que el servidor no
  /// aplica quitaría acceso en vez de explicarlo. Queda listo para el día que
  /// un plan devuelva `false`.
  static Future<bool> exigir(
    BuildContext context,
    String entitlement, {
    required Me? me,
    String? nombreFuncion,
  }) async {
    if (habilitado(me, entitlement)) return true;
    if (!context.mounted) return false;
    await mostrar(
      context,
      motivo: MotivoMuro.funcionNoIncluida,
      me: me,
      detalle: nombreFuncion == null
          ? null
          : '$nombreFuncion no está incluido en tu plan actual.',
    );
    return false;
  }
}

class _Dialogo extends StatelessWidget {
  const _Dialogo({
    required this.titulo,
    required this.explicacion,
    this.detalle,
  });

  final String titulo;
  final String explicacion;
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: JvShapes.rTarjeta),
      title: Text(titulo, style: JvText.cuerpoFuerte.copyWith(fontSize: 17)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (detalle != null) ...<Widget>[
            Text(detalle!, style: JvText.cuerpoMedio.copyWith(height: 1.5)),
            const SizedBox(height: 12),
          ],
          Text(
            explicacion,
            style: JvText.cuerpoMedio.copyWith(
              height: 1.55,
              color: JvColors.txtSecundario,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        // Un solo botón, y cierra. Aquí NO va ningún «Ver planes».
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(TextosMuro.botonCerrar),
        ),
      ],
    );
  }
}

/// Fila de facturación para Perfil.
///
/// Es la que faltaba: sin ella el usuario que quiere cancelar o cambiar de plan
/// no encuentra ningún sitio donde preguntar.
class FilaGestionarPlan extends StatelessWidget {
  const FilaGestionarPlan({super.key, required this.me});

  final Me? me;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool esPago = me?.esPago ?? false;

    return Material(
      color: cs.surface,
      borderRadius: JvShapes.rLista,
      child: InkWell(
        borderRadius: JvShapes.rLista,
        onTap: () => MuroPlan.mostrar(
          context,
          motivo: BillingPolicy.motivoPara(me),
          me: me,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: JvShapes.rLista,
            border: Border.all(color: cs.outline),
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.receipt_long_outlined,
                size: 18,
                color: JvColors.txtSecundario,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  TextosMuro.filaGestionar(esPago),
                  style: JvText.cuerpoMedio.copyWith(fontSize: 14),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: JvColors.txtTerciario,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
