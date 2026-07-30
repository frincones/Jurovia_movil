# credentials/

Carpeta para las llaves de firma y publicación. **Nada de aquí se sube al repo**
(ver `.gitignore`): solo se versiona este README.

| Archivo | Origen | Usado por |
| --- | --- | --- |
| `jurovia-upload.jks` | `keytool -genkey` (una sola vez) | firma del AAB de Android |
| `google-play-service-account.json` | Google Cloud IAM + permisos en Play Console | subida a Google Play |
| `AuthKey_XXXXXXXX.p8` | App Store Connect → Users and Access → Integrations | subida a TestFlight |
| `distribution.p12` | certificado Apple Distribution exportado | firma del IPA |
| `jurovia.mobileprovision` | provisioning profile App Store | firma del IPA |

Notas:

- El `.p8` de Apple **solo se puede descargar una vez**. Si se pierde, hay que
  revocar la llave y generar otra.
- Perder el keystore de Android **sin Play App Signing activo** significa no
  poder volver a publicar actualizaciones con el mismo paquete. Actívalo.
- En CI no se usan estos archivos: los workflows los reconstruyen desde secrets
  en base64 y los borran al terminar el job.

Instrucciones completas en [`../docs/DESPLIEGUE_TIENDAS.md`](../docs/DESPLIEGUE_TIENDAS.md).
