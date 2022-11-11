# インシデント体験(Timeout編)

## これはなに？

連携先のサービス、ミドルウェア等が何らかの原因でスローダウンを起こし、
レスポンスが返ってこない状況を再現したリポジトリです。Main Service から Accident Service にリクエストを送りますが、Accident Service がレスポンスを返すまで100secかかるため、Main Serviceではリクエストをさばけなることを観測できます。

また、Main Serviceでは Accident Service の状況に巻き込まれないよう、適切にタイムアウトを設定することで、 Accident Service に連携しない機能は利用できることを体験できます。

## 必要な環境

### a. GitHub Codespaces

このリポジトリを clone 後、Code ボタンから Codespaces を開いてください。

### b. その他の環境

- VSCode
  - VSCode Dev Containers Extension
  - VSCode Remote SSH Extension を組み合わせる場合の注意点
    - **AWS System Manager 等はサポートされていません**
- Docker
  - Docker Desktop (Windows & Mac)
    - WSL2でのDockerは Dev Containers が未サポート
  - Docker Community Edition (Linux)
    - docker-compose-plugin をインストールすること
    - Dev Containers がサポートするのは docker compose V2 のみ
    - **python版のdocker-composeはサポートされていません**

#### 立ち上げ方

1. このリポジトリを clone する
2. VSCode Dev Containers で開く
    - 自動でコンテナのビルド、Extensions のインストール、 bundle install を行います。
    - 数分かかるのでコーヒーを飲んで待ちましょう。

## 使い方

1. VSCode が起動したらターミナルを開き、下記のプロセスを立ち上げます
    - `bundle ex rails s`: メインのサービスを起動
2. 下記のようのPORTSタブを開いてください。
    ![PORTS Tab](/docs/images/port.png)
    - Local Addressに書かれているアドレスをブラウザで開くことを確認してください。この例では http://localhost:3001 です。
    - Rails へリクエストが到達することと、ブラウザでRailsのログが開くことを確認してください。
    - VSCode Docker Extension がコンテナ内で立ち上がったサービスを検知し、自動で Port Forwarding を行います。
3. もう一つTERMINALを開きましょう。
    ![TERMINAL Tab](/docs/images/terminal.png)

4. この環境には [hey](https://github.com/rakyll/hey) というHTTPリクエストベンチを導入しています。新しく作成したTERMINALで `hey -n 4 -c 2 http://localhost:3000/posts` とコマンドを起動後、ブラウザで先程開いたURLを再表示してください。**ブラウザは60secほど読み込み中の表示になるはずです。**

### なにがおきているのか？

Main Service の起動時の表示は下記のとおりです。

```shell
=> Booting Puma
=> Rails 7.0.4 application starting in development 
=> Run `bin/rails server --help` for more startup options
Puma starting in single mode...
* Puma version: 5.6.5 (ruby 3.1.2-p20) ("Birdie's Version")
*  Min threads: 2
*  Max threads: 2
*  Environment: development
*          PID: 7209
* Listening on http://127.0.0.1:3000
```

`Puma starting in single mode...` という表示から単一プロセスモードで起動しており、 `Min threads` も `Max threads` も `2` となっていることから、Main Serviceでは最大2リクエスト受け付けます。

`hey -n 4 -c 2 http://localhost:3000/posts` は `Main Service` の `/posts` にリクエストを送るエンドポイントを、 `-c 2` で2並列を指定し、 `-n 4` で 4リクエスト送らせています。 `/posts` は下記の実装になっています。

```ruby
  def index
    client = service_client
    resonse = client.get('/')
    # 便宜的に連携先サービスから取得してきたデータを表示する
    render plain: response.body
  rescue Faraday::TimeoutError => ex
    render file: Rails.root.join('public/408.html'), status: :request_timeout
  end

  private 

  def service_client
    if TIMEOUT.present?
      Rails.logger.info("timeout: #{TIMEOUT} sec")
      Faraday.new(
        'http://localhost:4567',
        request: { timeout: TIMEOUT}
      )
    else
      Rails.logger.info("timeout: 60 sec (default)")
      Faraday.new('http://localhost:4567')
    end
  end
```

`localhost:4567` は `Accident Service` が待ち受けています。このサービスは100sec sleepするため、Faradayのタイムアウトまで待ちます。試しに Main Service が起動しているターミナルに戻り、`SERVICE_TIMEOUT=10 bundle ex rails s` で起動後、 `hey` を起動していたターミナルで再度 `hey -n 4 -c 2 http://localhost:3000/posts` を実行し、ブラウザを再表示させてみてください。今度は**ブラウザは60secも待たずRailsのロゴを表示するはずです。**

Main Serviceが Accident Service へのリクエストを、10secでタイムアウトするように設定しています。そのため、Main Serviceはブラウザのリクエストを受け付けると即座にレスポンスを返すことができました。

今度は `RAILS_MAX_THREADS=4 bundle ex rails s` と指定しましょう。すると、同時に4リクエスト受け付けられる状態で起動します。先程紹介した `hey` コマンドを使って、同様のリクエストを送ってみてください。同時に2リクエストであれば、ブラウザのリクエストはレスポンスできているはずです。


さて、EKSなどkubernetes環境ではPodがリクエストを受け付けられるかを確認するため `/ready` を監視することが多いです。このエンドポイントも `/` と同様にブラウザから叩いてみてください。リクエストを受け付けられるPodが減ってきたことをEKSが検知すると、自動でPodの数を増やしますが、これにも限度があります。いずれはMain Serviceもリクエストがさばけなくなっていきます。連携先サービスの不調により、リクエストが詰まっていく動きが想像できたのではないでしょうか？

### システム構成

![System Digram](/docs/puml/incident-drill-timeout.svg)

#### Main Service

- `/`: Railsのロゴを表示する
- `/posts`: Accident Service の `/` にリクエストを送るエンドポイント
- `/ready`: このサービスがリクエストを受け付けられるか、Kubernetes 等から監視されるエンドポイント

#### Accident Service

Sinatraで実装されたWebサービスです。 .devcontainer/accident-service/ 配下にコードがあります。

- `/`: 100秒レスポンスを返さないエンドポイント。実装は下記の通り

```ruby
  get '/' do
    sleep 100
    'Hello world!'
  end
```