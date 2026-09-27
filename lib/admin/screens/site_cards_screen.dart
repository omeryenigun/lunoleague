import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kelimelig/admin/admin_directory.dart';
import 'package:kelimelig/admin/game_scope.dart';
import 'package:kelimelig/admin/site_card_api.dart';
import 'package:kelimelig/api/site_card_media.dart';
import 'package:kelimelig/core/config/api_config.dart';
import 'package:kelimelig/core/theme/colors.dart';

class SiteCardsScreen extends StatefulWidget {
  const SiteCardsScreen({super.key});

  @override
  State<SiteCardsScreen> createState() => _SiteCardsScreenState();
}

class _SiteCardsScreenState extends State<SiteCardsScreen> {
  Future<List<SiteCard>>? _load;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load ??= _api().list();
  }

  SiteCardApi _api() {
    final token = context.getInheritedWidgetOfExactType<AdminGameScope>()?.token;
    if (token == null || token.isEmpty) {
      throw AdminAuthException('Oturum geçersiz.');
    }
    return SiteCardApi(ApiConfig.baseUrl, token);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Oyun kartları')),
      body: FutureBuilder<List<SiteCard>>(
        future: _load!,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text('${snap.error}', style: const TextStyle(color: AppColors.danger)),
            );
          }
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final cards = snap.data ?? const <SiteCard>[];
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              for (final card in cards) ...[
                _CardTile(
                  card: card,
                  onOpen: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => SiteCardForm(cardId: card.id)),
                    );
                    if (!mounted) return;
                    setState(() => _load = _api().list());
                  },
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card, required this.onOpen});

  final SiteCard card;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 720),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _Thumb(url: card.iconUrl, size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                Text(
                  card.live ? 'Yayında' : 'Yakında',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          FilledButton(onPressed: onOpen, child: const Text('Düzenle')),
        ],
      ),
    );
  }
}

class SiteCardForm extends StatefulWidget {
  const SiteCardForm({super.key, required this.cardId});

  final String cardId;

  @override
  State<SiteCardForm> createState() => _SiteCardFormState();
}

class _SiteCardFormState extends State<SiteCardForm> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _nameEn = TextEditingController();
  final _descriptionEn = TextEditingController();
  final _playUrl = TextEditingController();
  final _iosUrl = TextEditingController();
  final _sort = TextEditingController();
  final _picker = ImagePicker();
  SiteCard? _card;
  var _status = 'soon';
  var _loading = true;
  var _busy = false;
  String? _error;

  SiteCardApi get _api {
    final token = context.getInheritedWidgetOfExactType<AdminGameScope>()?.token;
    if (token == null || token.isEmpty) {
      throw AdminAuthException('Oturum geçersiz.');
    }
    return SiteCardApi(ApiConfig.baseUrl, token);
  }

  @override
  void initState() {
    super.initState();
    _reload(fillText: true);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _nameEn.dispose();
    _descriptionEn.dispose();
    _playUrl.dispose();
    _iosUrl.dispose();
    _sort.dispose();
    super.dispose();
  }

  Future<void> _reload({required bool fillText}) async {
    try {
      final cards = await _api.list();
      final card = cards.where((item) => item.id == widget.cardId).firstOrNull;
      if (!mounted) return;
      setState(() {
        _card = card;
        _loading = false;
        _error = card == null ? 'Kart bulunamadı.' : null;
        if (card != null && fillText) {
          _name.text = card.name;
          _description.text = card.description;
          _nameEn.text = card.nameEn;
          _descriptionEn.text = card.descriptionEn;
          _playUrl.text = card.playUrl;
          _iosUrl.text = card.iosUrl;
          _sort.text = '${card.sortOrder}';
          _status = card.status;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _save({List<String>? imageOrder}) async {
    final card = _card;
    if (card == null) return;
    final sort = int.tryParse(_sort.text.trim());
    if (_name.text.trim().isEmpty || _description.text.trim().isEmpty || sort == null) {
      setState(() => _error = 'Ad, açıklama ve sıra gerekli.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final cards = await _api.save(
        card,
        name: _name.text.trim(),
        description: _description.text.trim(),
        nameEn: _nameEn.text.trim(),
        descriptionEn: _descriptionEn.text.trim(),
        playUrl: _playUrl.text.trim(),
        iosUrl: _iosUrl.text.trim(),
        status: _status,
        sortOrder: sort,
        imageOrder: imageOrder,
      );
      if (!mounted) return;
      setState(() => _card = cards.where((item) => item.id == widget.cardId).firstOrNull ?? card);
    } on AdminAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick({required bool icon}) async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null || _card == null) return;
    final bytes = await file.readAsBytes();
    final type = imageContentType(bytes);
    if (!mounted) return;
    if (type == null || bytes.length > siteMediaMaxBytes) {
      setState(() => _error = 'Yalnız 1,5 MB altındaki png, jpeg veya webp.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final cards = await _api.upload(_card!, bytes, type, icon: icon);
      if (!mounted) return;
      setState(() => _card = cards.where((item) => item.id == widget.cardId).firstOrNull);
    } on AdminAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(String mediaId) async {
    final card = _card;
    if (card == null) return;
    setState(() => _busy = true);
    try {
      final cards = await _api.removeImage(card, mediaId);
      if (!mounted) return;
      setState(() => _card = cards.where((item) => item.id == widget.cardId).firstOrNull);
    } on AdminAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _move(int index, int delta) async {
    final images = [...?_card?.images];
    final next = index + delta;
    if (next < 0 || next >= images.length) return;
    final item = images.removeAt(index);
    images.insert(next, item);
    await _save(imageOrder: [for (final image in images) image.id]);
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    return Scaffold(
      appBar: AppBar(title: Text(card?.name ?? 'Oyun kartı')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : card == null
              ? Center(child: Text(_error ?? 'Kart bulunamadı.'))
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _name,
                            decoration: const InputDecoration(labelText: 'Ad'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _description,
                            minLines: 3,
                            maxLines: 6,
                            decoration: const InputDecoration(labelText: 'Açıklama'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _nameEn,
                            decoration: const InputDecoration(labelText: 'Ad (English)'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _descriptionEn,
                            minLines: 3,
                            maxLines: 6,
                            decoration: const InputDecoration(labelText: 'Açıklama (English)'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _playUrl,
                            decoration: const InputDecoration(labelText: 'Google Play linki'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _iosUrl,
                            decoration: const InputDecoration(labelText: 'App Store linki'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _sort,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(labelText: 'Sıra'),
                          ),
                          const SizedBox(height: 16),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'live', label: Text('Yayında')),
                              ButtonSegment(value: 'soon', label: Text('Yakında')),
                            ],
                            selected: {_status},
                            onSelectionChanged: _busy
                                ? null
                                : (next) => setState(() => _status = next.first),
                          ),
                          const SizedBox(height: 20),
                          const Text('İkon', style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _Thumb(url: card.iconUrl, size: 72),
                              const SizedBox(width: 12),
                              OutlinedButton(
                                onPressed: _busy ? null : () => _pick(icon: true),
                                child: const Text('İkon seç'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const Expanded(
                                child: Text('Görseller', style: TextStyle(fontWeight: FontWeight.w800)),
                              ),
                              OutlinedButton(
                                onPressed: _busy ? null : () => _pick(icon: false),
                                child: const Text('Görsel ekle'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          for (var i = 0; i < card.images.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  _Thumb(url: card.images[i].url, size: 64),
                                  const Spacer(),
                                  IconButton(
                                    tooltip: 'Yukarı',
                                    onPressed: _busy || i == 0 ? null : () => _move(i, -1),
                                    icon: const Icon(Icons.arrow_upward),
                                  ),
                                  IconButton(
                                    tooltip: 'Aşağı',
                                    onPressed: _busy || i == card.images.length - 1
                                        ? null
                                        : () => _move(i, 1),
                                    icon: const Icon(Icons.arrow_downward),
                                  ),
                                  IconButton(
                                    tooltip: 'Sil',
                                    onPressed: _busy ? null : () => _remove(card.images[i].id),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(_error!, style: const TextStyle(color: AppColors.danger)),
                          ],
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _busy ? null : () => _save(),
                            child: const Text('Kaydet'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = url;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: image == null
          ? const Icon(Icons.image_outlined, color: AppColors.textSecondary)
          : Image.network(image, fit: BoxFit.cover),
    );
  }
}
