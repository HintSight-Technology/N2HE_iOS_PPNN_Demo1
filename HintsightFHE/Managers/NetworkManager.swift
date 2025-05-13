//
//  NetworkManager.swift
//  HintsightFHE
//
//  Created by Luo Kaiwen on 5/8/24.
//

import UIKit
import Combine


class NetworkManager {
    
    static let shared = NetworkManager()
    private let baseUrl = "https://fr-demo-03.hintsight.com"
    private var matchResult = ""
    private let extractor = SVFeatureExtractor()
    private var cancellables = Set<AnyCancellable>()
    
    
    func postUserEncAudioBio(for username: String, with userEncBioArr: [[Int64]])  -> String {
        guard let rlweSkPath = Bundle.main.path(forResource: "rlwe_sk", ofType: "txt") else {
            fatalError("Can't find rlwe_sk.txt file!")
        }
        
        var request = URLRequest(url: URL(string: self.baseUrl)!)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd-yyy_HH:mm:ss:SSS"
        let ID = dateFormatter.string(from: Date())

        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = [
            "id": ID,
            "name": username+"_audio",
            "feature_vector": userEncBioArr
        ] as [String : Any]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: .fragmentsAllowed)

        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else {
                return
            }

            do {
                _ = try JSONDecoder().decode(UserEncBio.self, from: data)
                print("POST SUCCESS")
            } catch {
                print("POST ERROR")
            }
            
            
            
            let urlString = self.baseUrl + "/" + username + "_audio_" + ID + ".json"
            let url = URL(string: urlString)!
            typealias DataTaskOutput = URLSession.DataTaskPublisher.Output

            let dataTaskPublisher = URLSession.shared.dataTaskPublisher(for: url)
            .tryMap({ (dataTaskOutput: DataTaskOutput) -> Result<DataTaskOutput, Error> in
                guard let httpResponse = dataTaskOutput.response as? HTTPURLResponse else {
                    return .failure(HSNetError.invalidResponse)
                }

                if httpResponse.statusCode == 404 {
                    throw HSNetError.invalidData
                }

                return .success(dataTaskOutput)
            })

            dataTaskPublisher
            .catch({ (error: Error) -> AnyPublisher<Result<URLSession.DataTaskPublisher.Output, Error>, Error> in
                
                switch error {
                case HSNetError.invalidData:
                    print("Received a retryable error")
                    return Fail(error: error)
                        .delay(for: 0.05, scheduler:  DispatchQueue.global())
                        .eraseToAnyPublisher()
                default:
                    print("Received a non-retryable error")
                    return Just(.failure(error))
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                }
            })
            .retry(50)
            .tryMap({ result in
                let response = try result.get()
                let json = try JSONDecoder().decode(UserEncResult.self, from: response.data)
                return json
            })
            .sink(receiveCompletion:  { _ in
                print("end of verification...")
            }, receiveValue: { value in
                print("value")
                let vector: [Int64] = value.result
                if let result = self.extractor.module.audioDecrypt(vector: vector.map { NSNumber(value: $0) }, fileAtPath: rlweSkPath) {
                    self.matchResult = result
                    print("result in network manager")
                    print(result)
                } else {
                    print("decryption error")
                }
            })
            .store(in: &self.cancellables)
        }
        task.resume()
        print("before return")
        print(matchResult)
        return matchResult
    }

}
