@preconcurrency import AVFoundation
import Dependencies

extension AudioPlayerClient: DependencyKey {
  static let liveValue = Self { data in
    let stream = AsyncThrowingStream<Bool, Error> { continuation in
      do {
        let delegate = try Delegate(
          data: data,
          didFinishPlaying: { successful in
            continuation.yield(successful)
            continuation.finish()
          },
          decodeErrorDidOccur: { error in
            continuation.finish(throwing: error)
          }
        )
          do {
              try AVAudioSession.sharedInstance().setCategory(.playback)
          } catch(let error) {
              print(error.localizedDescription)
          }
        delegate.player.play()
        continuation.onTermination = { _ in
          delegate.player.stop()
        }
      } catch {
        continuation.finish(throwing: error)
      }
    }
    return try await stream.first(where: { _ in true }) ?? false
  }
}

private final class Delegate: NSObject, AVAudioPlayerDelegate, Sendable {
  let didFinishPlaying: @Sendable (Bool) -> Void
  let decodeErrorDidOccur: @Sendable (Error?) -> Void
  let player: AVAudioPlayer

  init(
    data: Data,
    didFinishPlaying: @escaping @Sendable (Bool) -> Void,
    decodeErrorDidOccur: @escaping @Sendable (Error?) -> Void
  ) throws {
    self.didFinishPlaying = didFinishPlaying
    self.decodeErrorDidOccur = decodeErrorDidOccur
      self.player = try AVAudioPlayer(data: data)
    super.init()
    self.player.delegate = self
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    self.didFinishPlaying(flag)
  }

  func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
    self.decodeErrorDidOccur(error)
  }
}
