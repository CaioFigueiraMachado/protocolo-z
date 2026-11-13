/// Relógio sincronizado com o servidor.
///
/// O fim da expedição e a expiração das trocas vêm do banco (now()).
/// Se o relógio do celular estiver adiantado/atrasado, a contagem ficaria
/// errada; por isso guardamos a diferença entre o servidor e o aparelho.
class ServerClock {
  static Duration _offset = Duration.zero;

  static void sync(DateTime serverNow) {
    _offset = serverNow.toUtc().difference(DateTime.now().toUtc());
  }

  static DateTime now() => DateTime.now().toUtc().add(_offset);
}
