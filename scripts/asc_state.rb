# État d'une app sur App Store Connect, sans dépendance : le JWT ES256 est
# fabriqué avec OpenSSL de la stdlib. `sign` rend une signature DER ; l'API en
# attend la forme brute r||s sur 64 octets, d'où la conversion.
require "openssl"
require "base64"
require "json"
require "net/http"

def b64(s) = Base64.urlsafe_encode64(s).delete("=")

def token
  kid = ENV.fetch("ASC_KEY_ID")
  iss = ENV.fetch("ASC_ISSUER_ID")
  key = OpenSSL::PKey::EC.new(File.read(ENV.fetch("ASC_KEY_P8_PATH")))
  header  = b64({alg: "ES256", kid: kid, typ: "JWT"}.to_json)
  payload = b64({iss: iss, exp: Time.now.to_i + 900, aud: "appstoreconnect-v1"}.to_json)
  der = key.sign(OpenSSL::Digest.new("SHA256"), "#{header}.#{payload}")
  r, s = OpenSSL::ASN1.decode(der).value.map { |v| v.value.to_s(2).rjust(32, "\x00") }
  "#{header}.#{payload}.#{b64(r + s)}"
end

TOK = token
def get(path)
  uri = URI("https://api.appstoreconnect.apple.com/v1/#{path}")
  req = Net::HTTP::Get.new(uri, "Authorization" => "Bearer #{TOK}")
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| h.request(req) }
  abort("HTTP #{res.code} sur #{path}\n#{res.body}") unless res.code.to_i == 200
  JSON.parse(res.body)
end

# Le bundle se lit dans `project.yml` et nulle part ailleurs : c'est XcodeGen
# qui grave `PRODUCT_BUNDLE_IDENTIFIER` dans l'app, donc c'est ce fichier qui
# fait foi. Le recopier ici en donnerait une deuxième version, et c'est ce
# doublon qui fait qu'on livre un jour la fiche d'une app à une autre.
def app_bundle_id
  yml = File.read(File.expand_path("../project.yml", __dir__))
  # La cible `Salat` est la première du fichier ; le widget vient ensuite avec
  # son propre identifiant, qu'on ne veut surtout pas attraper.
  yml[/PRODUCT_BUNDLE_IDENTIFIER:\s*(\S+)/, 1] or
    abort("PRODUCT_BUNDLE_IDENTIFIER absent de project.yml")
end

bundle = app_bundle_id
apps = get("apps?filter[bundleId]=#{bundle}")
abort("Aucune fiche pour #{bundle}") if apps["data"].empty?
app = apps["data"].first
puts "app    : #{app['attributes']['name']} (#{app['id']})"

# Le build **attaché** à la version, et non la liste des builds montés : c'est
# lui que la revue examinera, et c'est la seule façon de vérifier qu'on n'a pas
# soumis l'avant-dernier.
versions = get("apps/#{app['id']}/appStoreVersions?limit=5&include=build")
builds_by_id = (versions["included"] || []).select { |i| i["type"] == "builds" }
                                           .to_h { |b| [b["id"], b.dig("attributes", "version")] }
versions["data"].each do |v|
  a = v["attributes"]
  attached = builds_by_id[v.dig("relationships", "build", "data", "id")]
  puts "version: #{a['versionString']} — #{a['appStoreState'] || a['appVersionState']}" \
       " (build #{attached || 'aucun'})"
end

get("apps/#{app['id']}/reviewSubmissions?limit=3")["data"].each do |r|
  a = r["attributes"]
  puts "revue  : #{a['state']} (soumise: #{a['submitted']})"
end

# Le classement d'âge vit sur l'`appInfo`, pas sur la version — c'est pour ça
# qu'il survit d'une version à l'autre, et pour ça qu'on le vérifie ici.
info = get("apps/#{app['id']}/appInfos?include=ageRatingDeclaration")
decl = (info["included"] || []).find { |i| i["type"] == "ageRatingDeclarations" }
if decl
  a = decl["attributes"]
  puts "âge    : gamblingSimulated=#{a['gamblingSimulated']} override=#{a['ageRatingOverrideV2']}"
end

get("builds?filter[app]=#{app['id']}&limit=8&sort=-version")["data"].each do |b|
  a = b["attributes"]
  puts "build  : #{a['version']} — #{a['processingState']} (expire: #{a['expired']})"
end
