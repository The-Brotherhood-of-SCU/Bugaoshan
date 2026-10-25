part of 'cloud_print_page.dart';

class _CloudPrintOptionsSheet extends StatefulWidget {
  const _CloudPrintOptionsSheet({required this.initial});
  final CloudPrintOptions initial;
  @override
  State<_CloudPrintOptionsSheet> createState() =>
      _CloudPrintOptionsSheetState();
}

class _CloudPrintOptionsSheetState extends State<_CloudPrintOptionsSheet> {
  final _form = GlobalKey<FormState>();
  late CloudPrintColor _color;
  late CloudPrintPaper _paper;
  late CloudPrintDuplex _duplex;
  late final TextEditingController _copies, _pages;
  @override
  void initState() {
    super.initState();
    _color = widget.initial.color;
    _paper = widget.initial.paper;
    _duplex = widget.initial.duplex;
    _copies = TextEditingController(text: '${widget.initial.copies}');
    _pages = TextEditingController(text: widget.initial.pages);
  }

  @override
  void dispose() {
    _copies.dispose();
    _pages.dispose();
    super.dispose();
  }

  CloudPrintOptions _value() => CloudPrintOptions(
    color: _color,
    paper: _paper,
    duplex: _duplex,
    copies: int.tryParse(_copies.text) ?? 0,
    pages: _pages.text.trim(),
  );
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.cloudPrintFileSettings,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<CloudPrintColor>(
              initialValue: _color,
              decoration: InputDecoration(labelText: l10n.cloudPrintColor),
              items: [
                DropdownMenuItem(
                  value: CloudPrintColor.monochrome,
                  child: Text(l10n.cloudPrintMono),
                ),
                DropdownMenuItem(
                  value: CloudPrintColor.color,
                  child: Text(l10n.cloudPrintFullColor),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _color = value);
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<CloudPrintPaper>(
              initialValue: _paper,
              decoration: InputDecoration(labelText: l10n.cloudPrintPaper),
              items: [
                const DropdownMenuItem(
                  value: CloudPrintPaper.a4,
                  child: Text('A4'),
                ),
                const DropdownMenuItem(
                  value: CloudPrintPaper.a3,
                  child: Text('A3'),
                ),
                DropdownMenuItem(
                  value: CloudPrintPaper.original,
                  child: Text(l10n.cloudPrintOriginal),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _paper = value);
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<CloudPrintDuplex>(
              initialValue: _duplex,
              decoration: InputDecoration(labelText: l10n.cloudPrintDuplex),
              items: [
                DropdownMenuItem(
                  value: CloudPrintDuplex.longEdge,
                  child: Text(l10n.cloudPrintLongEdge),
                ),
                DropdownMenuItem(
                  value: CloudPrintDuplex.shortEdge,
                  child: Text(l10n.cloudPrintShortEdge),
                ),
                DropdownMenuItem(
                  value: CloudPrintDuplex.simplex,
                  child: Text(l10n.cloudPrintSimplex),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _duplex = value);
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _copies,
              decoration: InputDecoration(labelText: l10n.cloudPrintCopies),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (_) {
                final value = int.tryParse(_copies.text);
                return value == null || value < 1 || value > 0xffffffff
                    ? l10n.cloudPrintInvalidCopies
                    : null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _pages,
              decoration: InputDecoration(
                labelText: l10n.cloudPrintPages,
                hintText: l10n.cloudPrintPagesHint,
              ),
              validator: (_) {
                try {
                  _value().toFields();
                  return null;
                } on FormatException {
                  return l10n.cloudPrintInvalidPages;
                }
              },
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(context, _value());
                }
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
