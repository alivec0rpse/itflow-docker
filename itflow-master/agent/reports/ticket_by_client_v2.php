<?php

require_once "includes/inc_all_reports.php";

enforceUserPermission('module_support');

/**
 * Convert seconds to "HH:MM:SS" (supports totals > 24h by using hours > 24)
 */
function secondsToHmsString($seconds) {
    $seconds = (int) max(0, $seconds);
    $hours = intdiv($seconds, 3600);
    $minutes = intdiv($seconds % 3600, 60);
    $secs = $seconds % 60;
    return sprintf('%02d:%02d:%02d', $hours, $minutes, $secs);
}

/**
 * 15-minute round up, return decimal hours in 0.25 increments
 * Examples:
 *  1 min  => 0.25
 *  16 min => 0.50
 *  61 min => 1.25
 */
function secondsToQuarterHourDecimal($seconds) {
    $seconds = (int) max(0, $seconds);
    if ($seconds === 0) return 0.00;

    $quarters = (int) ceil($seconds / 900); // 900 seconds = 15 minutes
    return $quarters * 0.25;
}

$year = isset($_GET['year']) ? (int) $_GET['year'] : (int) date('Y');
$month = isset($_GET['month']) ? (int) $_GET['month'] : (int) date('m');
if ($month < 1 || $month > 12) $month = (int) date('m');

$billable_only = (isset($_GET['billable_only']) && (int) $_GET['billable_only'] === 1) ? 1 : 0;

// Used for Year dropdown
$sql_ticket_years = mysqli_query($mysqli, "SELECT DISTINCT YEAR(ticket_created_at) AS ticket_year FROM tickets ORDER BY ticket_year DESC");

// Billable filter (adjust field name if yours differs)
$billable_sql = $billable_only ? " AND t.ticket_billable = 1 " : "";

/**
 * IMPORTANT:
 * This sums time worked ONLY for replies within the selected month/year
 * by filtering on tr.ticket_reply_created_at.
 * If your column name differs, replace ticket_reply_created_at accordingly.
 */
$stmt = $mysqli->prepare("
    SELECT
        c.client_id,
        c.client_name,
        t.ticket_id,
        t.ticket_prefix,
        t.ticket_number,
        t.ticket_subject,
        SEC_TO_TIME(COALESCE(SUM(TIME_TO_SEC(tr.ticket_reply_time_worked)), 0)) AS ticket_time_hms,
        COALESCE(SUM(TIME_TO_SEC(tr.ticket_reply_time_worked)), 0) AS ticket_time_seconds
    FROM tickets t
    INNER JOIN clients c
        ON c.client_id = t.ticket_client_id
    LEFT JOIN ticket_replies tr
        ON tr.ticket_reply_ticket_id = t.ticket_id
        AND tr.ticket_reply_time_worked IS NOT NULL
        AND YEAR(tr.ticket_reply_created_at) = ?
        AND MONTH(tr.ticket_reply_created_at) = ?
    WHERE c.client_archived_at IS NULL
      $billable_sql
    GROUP BY t.ticket_id
    HAVING ticket_time_seconds > 0
    ORDER BY c.client_name ASC, t.ticket_number ASC, t.ticket_id ASC
");
$stmt->bind_param("ii", $year, $month);
$stmt->execute();
$result = $stmt->get_result();

?>

<div class="card">
    <div class="card-header bg-dark py-2">
        <h3 class="card-title mt-2">
            <i class="fas fa-fw fa-life-ring mr-2"></i>
            Ticket By Client (<?php echo date("F", mktime(1, 1, 1, $month, 1)) . " " . $year; ?>)
            <?php if ($billable_only) { ?>
                <span class="badge badge-success ml-2">Billable Only</span>
            <?php } ?>
        </h3>
        <div class="card-tools">
            <button type="button" class="btn btn-primary d-print-none" onclick="window.print();">
                <i class="fas fa-fw fa-print mr-2"></i>Print
            </button>
        </div>
    </div>

    <div class="card-header d-print-none">

        <!-- Filters -->
        <form class="mb-3">
            <div class="row">
                <div class="col-md-3 mb-2">
                    <label class="mb-1">Year</label>
                    <select class="form-control" name="year">
                        <?php while ($row = mysqli_fetch_assoc($sql_ticket_years)) {
                            $ticket_year = (int) $row['ticket_year']; ?>
                            <option <?php if ($year === $ticket_year) echo 'selected'; ?> value="<?php echo $ticket_year; ?>">
                                <?php echo $ticket_year; ?>
                            </option>
                        <?php } ?>
                    </select>
                </div>

                <div class="col-md-4 mb-2">
                    <label class="mb-1">Month</label>
                    <select class="form-control" name="month">
                        <?php for ($m = 1; $m <= 12; $m++) { ?>
                            <option <?php if ($month === $m) echo 'selected'; ?> value="<?php echo $m; ?>">
                                <?php echo date("F", mktime(1, 1, 1, $m, 1)); ?>
                            </option>
                        <?php } ?>
                    </select>
                </div>

                <div class="col-md-3 mb-2 d-flex align-items-end">
                    <div class="custom-control custom-checkbox">
                        <input
                            type="checkbox"
                            class="custom-control-input"
                            id="billable_only"
                            name="billable_only"
                            value="1"
                            <?php if ($billable_only) echo 'checked'; ?>
                        >
                        <label class="custom-control-label" for="billable_only">Billable tickets only</label>
                    </div>
                </div>

                <div class="col-md-2 mb-2 d-flex align-items-end">
                    <button type="submit" class="btn btn-success btn-block">
                        <i class="fas fa-fw fa-filter mr-1"></i>Apply
                    </button>
                </div>
            </div>
        </form>
    </div>
</div>

<div class="card">
    <div class="table-responsive-sm">
        <table class="table table-striped">
            <thead class="bg-dark">
            <tr>
                <th>Ticket</th>
                <th class="text-right" style="width: 150px;">Time Worked</th>
                <th class="text-right" style="width: 120px;">Billable (hrs)</th>
            </tr>
            </thead>
            <tbody>
            <?php
            $current_client_id = null;
            $current_client_name = null;

            $client_ticket_count = 0;
            $client_time_seconds = 0;
            $client_billed_hours = 0.0;

            $grand_ticket_count = 0;
            $grand_time_seconds = 0;
            $grand_billed_hours = 0.0;

            $had_rows = false;

            while ($r = mysqli_fetch_assoc($result)) {
                $had_rows = true;

                $client_id = (int) $r['client_id'];
                $client_name = nullable_htmlentities($r['client_name']);

                $ticket_prefix = nullable_htmlentities($r['ticket_prefix']);
                $ticket_number = (int) $r['ticket_number'];
                $ticket_subject = nullable_htmlentities($r['ticket_subject']);

                $ticket_time_hms = $r['ticket_time_hms'];          // "HH:MM:SS"
                $ticket_time_seconds = (int) $r['ticket_time_seconds'];

                $ticket_billed_hours = secondsToQuarterHourDecimal($ticket_time_seconds);

                // Client break: print subtotal for previous client
                if ($current_client_id !== null && $client_id !== $current_client_id) {
                    ?>
                    <tr class="font-weight-bold">
                        <td class="text-right">
                            Total for <?php echo $current_client_name; ?> (<?php echo $client_ticket_count; ?> tickets)
                        </td>
                        <td class="text-right"><?php echo formatDuration(secondsToHmsString($client_time_seconds)); ?></td>
                        <td class="text-right"><?php echo number_format($client_billed_hours, 2); ?></td>
                    </tr>
                    <tr><td colspan="3"></td></tr>
                    <?php

                    $client_ticket_count = 0;
                    $client_time_seconds = 0;
                    $client_billed_hours = 0.0;
                }

                // Client header
                if ($client_id !== $current_client_id) {
                    $current_client_id = $client_id;
                    $current_client_name = $client_name;
                    ?>
                    <tr class="table-active">
                        <td colspan="3" class="font-weight-bold"><?php echo $client_name; ?></td>
                    </tr>
                    <?php
                }

                $display_ticket = trim($ticket_prefix . $ticket_number);
                if ($display_ticket === '') $display_ticket = (string) $ticket_number;

                ?>
                <tr>
                    <td><?= "$display_ticket - $ticket_subject" ?></td>
                    <td class="text-right"><?php echo formatDuration($ticket_time_hms); ?></td>
                    <td class="text-right"><?php echo number_format($ticket_billed_hours, 2); ?></td>
                </tr>
                <?php

                // Totals
                $client_ticket_count++;
                $client_time_seconds += $ticket_time_seconds;
                $client_billed_hours += $ticket_billed_hours;

                $grand_ticket_count++;
                $grand_time_seconds += $ticket_time_seconds;
                $grand_billed_hours += $ticket_billed_hours;
            }

            if (!$had_rows) {
                ?>
                <tr>
                    <td colspan="3" class="text-center text-muted">No tickets with time worked found for this month.</td>
                </tr>
                <?php
            } else {
                // Final client subtotal
                ?>
                <tr class="font-weight-bold">
                    <td class="text-right">
                        Total for <?php echo $current_client_name; ?> (<?php echo $client_ticket_count; ?> tickets)
                    </td>
                    <td class="text-right"><?php echo formatDuration(secondsToHmsString($client_time_seconds)); ?></td>
                    <td class="text-right"><?php echo number_format($client_billed_hours, 2); ?></td>
                </tr>

                <tr><td colspan="3"></td></tr>

                <!-- Grand totals -->
                <tr class="font-weight-bold">
                    <td class="text-right">
                        Grand Total (<?php echo $grand_ticket_count; ?> tickets)
                    </td>
                    <td class="text-right"><?php echo formatDuration(secondsToHmsString($grand_time_seconds)); ?></td>
                    <td class="text-right"><?php echo number_format($grand_billed_hours, 2); ?></td>
                </tr>
                <?php
            }
            ?>
            </tbody>
        </table>

        <small class="text-muted p-2">
            Billed hours are calculated per ticket by rounding that ticket’s worked time up to the nearest 15 minutes (0.25 hours).
        </small>
    </div>
</div>

<?php
require_once "../../includes/footer.php";
