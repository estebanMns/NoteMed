/// TSK-19 · HU05: pantalla modal para ingresar la firma digital y la tarjeta
/// profesional de la enfermera.
library;

import 'package:flutter/material.dart';

import 'firma_enfermera.dart';

/// Abre el modal. Devuelve la firma o `null` si se cancela.
Future<FirmaEnfermera?> mostrarFirmaModal(
  BuildContext context, {
  String? tarjetaInicial,
  DateTime Function() ahora = DateTime.now,
}) => showModalBottomSheet<FirmaEnfermera>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  // El lienzo usa el arrastre; no debe cerrar el modal.
  enableDrag: false,
  builder: (_) => FirmaModal(tarjetaInicial: tarjetaInicial, ahora: ahora),
);

class FirmaModal extends StatefulWidget {
  const FirmaModal({super.key, this.tarjetaInicial, this.ahora = DateTime.now});

  final String? tarjetaInicial;
  final DateTime Function() ahora;

  @override
  State<FirmaModal> createState() => _FirmaModalState();
}

class _FirmaModalState extends State<FirmaModal> {
  final List<List<Offset>> _trazos = [];
  late final _tarjeta = TextEditingController(text: widget.tarjetaInicial);
  bool _intentoAceptar = false;

  @override
  void dispose() {
    _tarjeta.dispose();
    super.dispose();
  }

  bool get _puedeAceptar =>
      FirmaEnfermera.trazosValidos(_trazos) &&
      FirmaEnfermera.validarTarjeta(_tarjeta.text) == null;

  void _aceptar() {
    setState(() => _intentoAceptar = true);
    if (!_puedeAceptar) return;
    Navigator.of(context).pop(
      FirmaEnfermera(
        trazos: [for (final t in _trazos) List.unmodifiable(t)],
        tarjetaProfesional: _tarjeta.text.trim().toUpperCase(),
        fecha: widget.ahora(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final sinFirma = _intentoAceptar && !FirmaEnfermera.trazosValidos(_trazos);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Firma de la enfermera',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Container(
            height: 180,
            decoration: BoxDecoration(
              border: Border.all(
                color: sinFirma ? esquema.error : esquema.outline,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.hardEdge,
            child: GestureDetector(
              key: const Key('firma-lienzo'),
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) => setState(() => _trazos.add([d.localPosition])),
              onPanUpdate: (d) =>
                  setState(() => _trazos.last.add(d.localPosition)),
              child: CustomPaint(
                painter: _PintorFirma(_trazos, esquema.onSurface),
                child: _trazos.isEmpty
                    ? Center(
                        child: Text(
                          'Firme aquí con el dedo',
                          style: TextStyle(color: esquema.outline),
                        ),
                      )
                    : const SizedBox.expand(),
              ),
            ),
          ),
          if (sinFirma)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Dibuje su firma',
                style: TextStyle(color: esquema.error),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const Key('firma-limpiar'),
              onPressed: () => setState(_trazos.clear),
              icon: const Icon(Icons.cleaning_services_outlined),
              label: const Text('Limpiar'),
            ),
          ),
          TextField(
            key: const Key('firma-tarjeta'),
            controller: _tarjeta,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Tarjeta profesional',
              prefixIcon: const Icon(Icons.badge_outlined),
              border: const OutlineInputBorder(),
              errorText: _intentoAceptar
                  ? FirmaEnfermera.validarTarjeta(_tarjeta.text)
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('firma-aceptar'),
                  onPressed: _aceptar,
                  child: const Text('Aceptar y firmar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PintorFirma extends CustomPainter {
  _PintorFirma(this.trazos, this.color) : _version = _contar(trazos);

  final List<List<Offset>> trazos;
  final Color color;
  final int _version;

  static int _contar(List<List<Offset>> t) =>
      t.fold(0, (a, trazo) => a + trazo.length);

  @override
  void paint(Canvas canvas, Size size) {
    final lapiz = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final t in trazos) {
      if (t.length == 1) {
        canvas.drawCircle(t.first, 1.25, lapiz..style = PaintingStyle.fill);
        lapiz.style = PaintingStyle.stroke;
        continue;
      }
      final camino = Path()..moveTo(t.first.dx, t.first.dy);
      for (final p in t.skip(1)) {
        camino.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(camino, lapiz);
    }
  }

  // La lista de trazos se modifica en el lugar; se compara por cantidad de
  // puntos para saber si hay que repintar.
  @override
  bool shouldRepaint(_PintorFirma old) =>
      old._version != _version || old.color != color;
}
