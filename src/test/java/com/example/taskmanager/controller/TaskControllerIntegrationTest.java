package com.example.taskmanager.controller;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.ResponseEntity;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class TaskControllerIntegrationTest {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void slowDbReadTakesMoreThanOneSecond() {
        ResponseWithElapsed response = getWithElapsed("/tasks/api/test/slow-db-read?delayMs=1100&dbDelayMs=600");

        assertThat(response.statusCode).isEqualTo(200);
        assertThat(response.body).containsEntry("type", "slow-db-read");
        assertThat(response.elapsedMs).isGreaterThanOrEqualTo(1000);
    }

    @Test
    void slowDbWriteTakesMoreThanOneSecond() {
        ResponseWithElapsed response = getWithElapsed("/tasks/api/test/slow-db-write?delayMs=1100&dbDelayMs=600");

        assertThat(response.statusCode).isEqualTo(200);
        assertThat(response.body).containsEntry("type", "slow-db-write");
        assertThat(response.elapsedMs).isGreaterThanOrEqualTo(1000);
    }

    private ResponseWithElapsed getWithElapsed(String path) {
        long startNs = System.nanoTime();
        ResponseEntity<Map> response = restTemplate.getForEntity(path, Map.class);
        long elapsedMs = (System.nanoTime() - startNs) / 1_000_000;

        return new ResponseWithElapsed(response.getStatusCodeValue(), response.getBody(), elapsedMs);
    }

    private static class ResponseWithElapsed {
        private final int statusCode;
        private final Map body;
        private final long elapsedMs;

        private ResponseWithElapsed(int statusCode, Map body, long elapsedMs) {
            this.statusCode = statusCode;
            this.body = body;
            this.elapsedMs = elapsedMs;
        }
    }
}
