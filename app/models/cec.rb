# == Schema Information
# Schema version: 20101005005317
#
# Table name: cecs
#
#  id               :integer         not null, primary key
#  nome_do_cliente  :string(255)
#  numero_do_pedido :string(255)
#  endereco         :string(255)
#  complemento      :string(255)
#  bairro           :string(255)
#  cidade           :string(255)
#  created_at       :datetime
#  updated_at       :datetime
#  cep              :string(255)
#  distancia        :decimal(, )
#  latitude         :decimal(, )
#  longitude        :decimal(, )
#  valor            :decimal(, )
#  comercial        :boolean
#  data_da_entrega  :date
#

class Cec < ActiveRecord::Base
  validates_presence_of [:cep, :nome_do_cliente, :numero_do_pedido, :endereco, :complemento, :bairro, :cidade, :valor], :message => "não pode estar em branco"

  before_validation :busca_cep  
  before_validation :preenche_endereco
  
  acts_as_mappable :default_units => :kms, 
                     :default_formula => :sphere, 
                     :distance_field_name => :distancia,
                     :lat_column_name => :latitude,
                     :lng_column_name => :longitude,
                     :auto_geocode=> {:field=>:endereco_completo, :error_message=>'Não foi possível identificar o endereço'}
  
  default_scope order('cep')
  
  def self.proximas_entregas
    find(:all, :select => "data_da_entrega", :group => "data_da_entrega", :order =>"data_da_entrega", :having => "data_da_entrega >= #{Date.today}")
  end
  
  def localizacao_base
    GeoKit::LatLng.new(-23.5499232, -46.6598365)
  end
  
  def distancia_da_farmacia
    distance_from(localizacao_base, :units => :kms)
  end
  
  def cep=(numero)
    self[:cep] =  numero.to_s.gsub(/\./, '').gsub(/\-/, '')
  end
  
  def endereco_completo
    "#{self[:endereco]}, #{self[:complemento]}, #{self[:bairro]}, #{self[:cidade]}, SP, Brasil"
  end
  
  
  def map
    this_map = GoogleMap::Map.new
		this_map.center = GoogleMap::Point.new(latitude, longitude) #SEATTLE WASHINGTON
		this_map.zoom = 16 #200km
		this_map.markers << GoogleMap::Marker.new(:map => this_map, 
                                         			:lat => latitude, 
                                         			:lng => longitude,
                                         			:html => nome_do_cliente)
		this_map
  end
  
  private
  
    def preenche_endereco
      begin
        endereco_do_cep = BuscaEndereco.por_cep(self[:cep]) 
        unless endereco_do_cep.nil?
          self[:endereco] = endereco_do_cep[0] + " " + endereco_do_cep[1]
          self[:bairro] = endereco_do_cep[2]
          self[:cidade] = endereco_do_cep[4]
          # do_geo_code
        end
      rescue
        errors.add("cep","informado é inválido")
      end 
    end
    
    def busca_cep
      if cep.blank?
        if self[:endereco].blank? or self[:complemento].blank? or self[:bairro].blank? or self[:cidade].blank? 
          errors.add_to_base("Endereço, complemento, bairro e cidade devem estar preenchidos para efetuar a busca de CEP")
        else
          geo=Geokit::Geocoders::MultiGeocoder.geocode (endereco_completo)
          if geo.success
            self[:cep] = geo.zip
          else
            errors.add_to_base("Não foi possível encontrar o endereço: #{endereco_completo}, especifique melhor.")
          end
        end
      end
    end

  
end
