// Ajax Modal Load Script (deduped + locked)
function hashKey(str) {
    let h = 0;
    for (let i = 0; i < str.length; i++) {
        h = ((h << 5) - h + str.charCodeAt(i)) | 0;
    }
    return Math.abs(h).toString(36);
}

$(document).on('click', '.ajax-modal', function (e) {
    e.preventDefault();

    const $trigger = $(this);

    // prevent spam clicks on same trigger
    if ($trigger.data('ajaxModalLoading')) {
        return;
    }

    $trigger
        .data('ajaxModalLoading', true)
        .prop('disabled', true)
        .addClass('disabled');

    // Prefer data-modal-url, fallback to href
    const modalUrl = $trigger.data('modal-url') || $trigger.attr('href') || '#';
    const modalSize = $trigger.data('modal-size') || 'md';

    if (!modalUrl || modalUrl === '#') {
        console.warn('ajax-modal: No modal URL found on trigger:', this);

        $trigger
            .data('ajaxModalLoading', false)
            .prop('disabled', false)
            .removeClass('disabled');

        return;
    }

    // stable IDs based on URL (prevents duplicates)
    const key = hashKey(String(modalUrl));
    const modalId = 'ajaxModal_' + key;
    const spinnerId = 'modal-loading-spinner-' + key;

    // if modal already exists, just show it
    const $existing = $('#' + modalId);
    if ($existing.length) {
        $existing.modal('show');

        $trigger
            .data('ajaxModalLoading', false)
            .prop('disabled', false)
            .removeClass('disabled');

        return;
    }

    // Show loading spinner while fetching content (deduped)
    $('#' + spinnerId).remove();
    $('.content-wrapper').append(`
        <div id="${spinnerId}" class="text-center p-5">
            <i class="fas fa-spinner fa-spin fa-2x text-muted"></i>
        </div>
    `);

    $.ajax({
        url: modalUrl,
        method: 'GET',
        dataType: 'json'
    })
    .done(function (response) {
        $('#' + spinnerId).remove();

        if (response && response.error) {
            alert(response.error);
            return;
        }

        // guard against race: if another request already created it
        if ($('#' + modalId).length) {
            $('#' + modalId).modal('show');
            return;
        }

        const modalHtml = `
            <div class="modal fade" id="${modalId}" tabindex="-1">
                <div class="modal-dialog modal-${modalSize}">
                    <div class="modal-content border-dark">
                        ${response.content || ''}
                    </div>
                </div>
            </div>`;

        $('.content-wrapper').append(modalHtml);

        const $modal = $('#' + modalId);
        $modal.modal('show');

        $modal.on('hidden.bs.modal', function () {
            $(this).remove();
        });
    })
    .fail(function (xhr, status, error) {
        $('#' + spinnerId).remove();
        alert('Error loading modal content. Please try again.');
        console.error('Modal AJAX Error:', status, error);
    })
    .always(function () {
        $trigger
            .data('ajaxModalLoading', false)
            .prop('disabled', false)
            .removeClass('disabled');
    });
});
