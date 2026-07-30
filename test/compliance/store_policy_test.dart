import 'package:flutter_test/flutter_test.dart';
import 'package:jurovia/compliance/ai_consent/ai_consent_gate.dart';
import 'package:jurovia/compliance/store_policy.dart';

/// Pruebas de cumplimiento de tienda.
///
/// ⚠️ **Estas pruebas no se borran ni se ajustan para que pasen.**
/// Si una falla, es que alguien introdujo un cambio que hace rechazable la app.
/// Fallar aquí cuesta un *pull request*; fallar en revisión de Apple cuesta
/// semanas.
void main() {
  group('StorePolicy · invariantes de tienda', () {
    test('la app no vende dentro (Apple 3.1.1 / Google Play Billing)', () {
      expect(
        StorePolicy.allowsInAppPurchase,
        isFalse,
        reason:
            'Modelo Web2App: se cobra en juroviapp.com con Paddle. '
            'Vender dentro sin IAP implementado = rechazo seguro.',
      );
    });

    test(
      'no hay enlaces de compra externos (Apple 3.1.3, mercado Colombia)',
      () {
        expect(
          StorePolicy.allowsExternalPurchaseLink,
          isFalse,
          reason:
              'El enlace externo solo se permite en la tienda de EE. UU. '
              'Incluye texto que sugiera pagar fuera, no solo enlaces.',
        );
      },
    );

    test('sin SDK publicitario → ATT no aplica', () {
      expect(
        StorePolicy.hasAdvertisingSdk,
        isFalse,
        reason:
            'Añadir uno obliga a App Tracking Transparency, a declarar '
            'dominios de rastreo en el privacy manifest y abre una categoría '
            'entera de rechazos.',
      );
    });

    test('sin login de terceros → la regla 4.8 no aplica', () {
      expect(
        StorePolicy.hasThirdPartyLogin,
        isFalse,
        reason:
            'Si se añade Google Sign-In, Apple exige también '
            'Sign in with Apple (guideline 4.8).',
      );
    });

    test('el proveedor de IA está nombrado explícitamente', () {
      // Apple 5.1.2(i) exige identificar al tercero por nombre.
      expect(StorePolicy.aiProvider, contains('Anthropic'));
      expect(StorePolicy.aiProvider, isNot('servicios de terceros'));
    });
  });

  group('AiConsentGate · Apple 5.1.2(i)', () {
    test('sin consentimiento, el agente es inalcanzable', () {
      expect(AiConsentGate.canUseAgent(null), isFalse);
      expect(AiConsentGate.canUseAgent(AiConsent.ninguno), isFalse);
      expect(AiConsentGate.tokenPara(AiConsent.ninguno), isNull);
    });

    test('con consentimiento vigente, se emite el token', () {
      final AiConsent c = AiConsentGate.otorgar(DateTime(2026, 7, 28));
      expect(AiConsentGate.canUseAgent(c), isTrue);
      expect(AiConsentGate.tokenPara(c), isNotNull);
    });

    test('un consentimiento de versión anterior obliga a re-consentir', () {
      const AiConsent viejo = AiConsent(aceptado: true, version: 0);
      expect(
        AiConsentGate.canUseAgent(viejo),
        isFalse,
        reason:
            'Subir AiConsentGate.version debe invalidar los consentimientos '
            'previos: cambió el proveedor, los datos o la finalidad.',
      );
    });

    test('aceptar sin marcar la casilla no cuenta', () {
      const AiConsent noAceptado = AiConsent(aceptado: false, version: 1);
      expect(AiConsentGate.canUseAgent(noAceptado), isFalse);
    });

    test('la pantalla debe listar los datos que se comparten', () {
      // No basta con decir "tus datos": hay que enumerarlos.
      expect(AiConsentGate.datosCompartidos, isNotEmpty);
      expect(AiConsentGate.datosCompartidos.length, greaterThanOrEqualTo(3));
    });
  });
}
