require "./model_action"

abstract class ReorderChildrenAction < Orma::ModelAction
  SUBJECT_ID_FIELD_NAME = "subject_id"
  TARGET_ID_FIELD_NAME = "target_id"

  controller do
    unless body = ctx.request.body
      ctx.response.status = :bad_request
      return true
    end

    subject_id = nil
    target_id = nil
    HTTP::Params.parse(body.gets_to_end) do |key, value|
      case key
      when SUBJECT_ID_FIELD_NAME
        subject_id = value.to_i32
      when TARGET_ID_FIELD_NAME
        target_id = value.to_i32
      end
    end

    subject = association.where(id: subject_id).first
    target = association.where(id: target_id).first

    items = association.order_by_sort_order!.to_a
    if i = items.index(target)
      items.delete(subject)
      if i >= items.size
        items.push(subject)
      else
        items.insert(i, subject)
      end
    end

    items.each_with_index do |item, index|
      item.sort_order = index + 1
      item.save
    end

    ctx.response.status = :created
  end

  view do
    delegate :association, :child_view, to: action

    stimulus_controller DragController do
      targets :subject_id, :target_id, :submit

      action :dragstart do |event|
        event.dataTransfer.setData("text/plain", event.target.dataset.reorderChildrenActionSubjectId)
        event.dataTransfer.allowedEffect = "move" # not sure if this is needed?
      end

      action :drag do |event|
        if event.clientY > (window.outerHeight - 120) && window.scrollY < document.body.clientHeight
          window.scrollTo({"top" => window.scrollY + 10})
        elsif event.clientY < 120 && window.scrollY > 0
          window.scrollTo({"top" => window.scrollY - 10})
        end
      end

      action :dragover do |event|
        event.preventDefault._call
        return true
      end

      action :dragenter do |event|
        event.preventDefault._call
      end

      action :drop do |event|
        subject_id = event.dataTransfer.getData("text/plain")
        draggedElement = this.element.querySelector("[data-reorder-children-action-subject-id='" + subject_id + "']")
        target = event.target.closest("[draggable=\"true\"]")
        target_id = target.dataset.reorderChildrenActionSubjectId
        positionComparison = target.compareDocumentPosition(draggedElement)

        this.subjectIdTarget.value = subject_id
        this.targetIdTarget.value = target_id

        if positionComparison & 4
          target.insertAdjacentElement("beforebegin", draggedElement)
        elsif positionComparison & 2
          target.insertAdjacentElement("afterend", draggedElement)
        end

        event.preventDefault._call

        this.submitTarget.click._call
      end

      action :dragend do
      end
    end

    record SubjectId, id : Int64 | Int32 | Nil do
      ToHtml.instance_tag_attrs do
        data_reorder_children_action_subject_id = id
      end
    end

    template do
      div DragController, DragController.dragstart_action("dragstart"), DragController.drag_action("drag"), DragController.dragover_action("dragover"), DragController.dragenter_action("dragenter"), DragController.drop_action("drop"), DragController.dragend_action("dragend") do
        action_form(hidden: true).to_html do
          input DragController.subject_id_target, type: :hidden, name: SUBJECT_ID_FIELD_NAME
          input DragController.target_id_target, type: :hidden, name: TARGET_ID_FIELD_NAME
          input DragController.submit_target, type: :submit, name: "submit", value: "submit"
        end
        div do
          association.each do |child|
            div SubjectId.new(child.id.try(&.value)), draggable: "true" do
              child_view(child)
            end
          end
        end
      end
    end
  end
end
