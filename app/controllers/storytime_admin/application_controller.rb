module StorytimeAdmin
  class ApplicationController < StorytimeAdmin.base_controller.constantize
    include StorytimeAdmin::Concerns::PolymorphicRouteGeneration

    layout :set_layout

    before_action :authenticate_user!
    before_action :ensure_admin!
    before_action :load_model, only: [:edit, :update, :destroy]

    helper_method :model, :model_display_name, :model_display_name_pluralized, :model_name, 
                  :model_sym, :sort_column, :sort_direction,  :admin_controller?, :headers,
                  :form_attributes, :index_attr, :current_user, :polymorphic_route_components

    def index
      @collection = model.all.order("#{sort_column} #{sort_direction}").page(params[:page]).per(20)
    end

    def new
      @model = model.new
    end

    def edit
    end

    def create
      @model = model.new(permitted_params)
      @model.user = current_user if @model.respond_to? :user

      if @model.save
        redirect_to polymorphic_route_components(model), notice: "#{model_name} successfully created"
      else
        render :new
      end
    end

    def update
      if @model.update(permitted_params)
        redirect_to polymorphic_route_components(model), notice: "#{model_name} successfully updated"
      else
        render :edit
      end
    end

    def destroy
      @model.destroy
      redirect_to polymorphic_route_components(model), notice: "#{model_name} successfully deleted"
    end

  private
    def permitted_params
      params.require(model.name.underscore.split("/").last).permit(permitted_attributes.map(&:to_sym))
    end

    def ensure_admin!
      unless current_user && admin_check
        redirect_to main_app.root_url, flash: { error: "Only admin users can access this page" }
      end
    end

    def admin_check
      if StorytimeAdmin.ensure_admin_scope.nil?
        current_user.send(StorytimeAdmin.ensure_admin_method)
      else
        current_user.send(StorytimeAdmin.ensure_admin_method, send(StorytimeAdmin.ensure_admin_scope))
      end
    end

    def attributes 
      @attributes ||= model.columns.map(&:name)
    end

    def form_attributes
      @form_attributes ||= attributes.reject{ |v| form_blacklist.include?(v) }
    end

    def permitted_attributes
      @permitted_attributes ||= attributes.reject{ |v| permitted_params_blacklist.include?(v) }
    end

    def form_blacklist
      ["id", "created_at", "updated_at"]
    end

    def permitted_params_blacklist
      ["id", "created_at", "updated_at"]
    end

    def index_attr
      if attributes.include?("title")
        ["title"]
      elsif attributes.include?("name")
        ["name"]
      else
        ["id"]
      end
    end

    def load_model
      @model = model.find(params[:id])
    end

    def model
      model_name.classify.constantize
    end

    def model_display_name
      model_name.split("::").last
    end

    def model_display_name_pluralized
      model_display_name.pluralize
    end

    def model_name
      @model_name ||= self.class.name.gsub("Controller", "").gsub("StorytimeAdmin::", "").singularize
    end

    def model_sym
      @model_sym ||= model.name.underscore.gsub("/", "_").to_sym
    end

    def sort_column
      model.column_names.include?(params[:sort]) ? params[:sort] : "#{model_name.underscore.pluralize}.id"
    end

    def sort_direction
      %w[asc desc].include?(params[:direction]) ? params[:direction] : "asc"
    end

    def admin_controller?
      true
    end

    def set_layout
      StorytimeAdmin.layout unless StorytimeAdmin.layout.nil?
    end

    if StorytimeAdmin.user_class_symbol != :user
      def current_user
        send("current_#{Admin.user_class_underscore_all}".to_sym)
      end
    end

  end
end
